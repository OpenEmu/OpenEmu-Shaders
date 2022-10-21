// Copyright (c) 2019, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import XCTest

@testable import OpenEmuShaders

class SlangShaderTests: XCTestCase {
    override func setUp() {
        InMemProtocol.requests = [:]
    }
    
    func testEmpty() {
        let cfg =
            """
            shaders = 0
            """
        InMemProtocol.requests = [
            "mem:///root/foo.slangp": cfg,
        ]
        
        let url = URL(string: "mem:///root/foo.slangp")!
        do {
            let ss = try SlangShader(fromURL: url)
            XCTAssertEqual(ss.passes.count, 0)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testOneFile() {
        let cfg =
            """
            shaders = 1
            shader0 = mem:///root/foo.slang
            """
        
        let src =
            """
            #version 450

            #pragma name this_is_the_name

            #pragma stage vertex
            // vertex
            #pragma stage fragment
            // fragment
            """
        InMemProtocol.requests = [
            "mem:///root/foo.slangp": cfg,
            "mem:///root/foo.slang": src,
        ]
        
        let url = URL(string: "mem:///root/foo.slangp")!
        do {
            let ss = try SlangShader(fromURL: url)
            XCTAssertEqual(ss.passes.count, 1)
            XCTAssertEqual(ss.passes[0].alias, "this_is_the_name")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testShaderPassDefaultProperties() {
        let cfg =
            """
            shaders = 1

            # shader zero verifies defaults
            shader0 = mem:///root/foo.slang
            """
        
        InMemProtocol.requests = [
            "mem:///root/foo.slangp": cfg,
            "mem:///root/foo.slang": "#version 450",
        ]
        
        let url = URL(string: "mem:///root/foo.slangp")!
        do {
            let ss = try SlangShader(fromURL: url)
            XCTAssertEqual(ss.passes.count, 1)
            
            let pass = ss.passes[0]
            XCTAssertEqual(pass.url, URL(string: "mem:///root/foo.slang")!)
            XCTAssertEqual(pass.frameCountMod, 0)
            XCTAssertNil(pass.scaleX)
            XCTAssertNil(pass.scaleY)
            XCTAssertEqual(pass.format, .bgra8Unorm)
            XCTAssertEqual(pass.filter, .unspecified)
            XCTAssertEqual(pass.wrapMode, .border)
            XCTAssertFalse(pass.isFloat)
            XCTAssertFalse(pass.issRGB)
            XCTAssertFalse(pass.isMipmap)
            XCTAssertNil(pass.alias)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testShaderPassFrameCountMod() {
        let cfg =
            """
            shaders = 3

            # shader zero verifies defaults
            shader0 = mem:///root/foo.slang

            shader1 = mem:///root/foo.slang
            frame_count_mod1 = 1

            shader2 = mem:///root/foo.slang
            frame_count_mod2 = 100

            """
        
        InMemProtocol.requests = [
            "mem:///root/foo.slangp": cfg,
            "mem:///root/foo.slang": "#version 450",
        ]
        
        let url = URL(string: "mem:///root/foo.slangp")!
        do {
            let ss = try SlangShader(fromURL: url)
            XCTAssertEqual(ss.passes.map(\.frameCountMod), [0, 1, 100])
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testShaderPassScale() {
        let cfg =
            """
            shaders = 14

            # shader zero verifies defaults
            shader0 = mem:///root/foo.slang

            # absolute

            shader1 = mem:///root/foo.slang
            scale_type1 = absolute

            shader2 = mem:///root/foo.slang
            scale_type2 = absolute
            scale_x2    = 100
            scale_y2    = 200

            shader3 = mem:///root/foo.slang
            scale_type_x3 = absolute
            scale_x3      = 100
            scale_type_y3 = source

            # source

            shader4 = mem:///root/foo.slang
            scale_type4 = source

            shader5 = mem:///root/foo.slang
            scale_type5 = source
            scale_x5    = 0.25
            scale_y5    = 0.55

            shader6 = mem:///root/foo.slang
            scale_type_x6 = source
            scale_x6      = 2.5
            scale_type_y6 = source

            # viewport

            shader7 = mem:///root/foo.slang
            scale_type7 = viewport

            shader8 = mem:///root/foo.slang
            scale_type8 = viewport
            scale_x8    = 0.25
            scale_y8    = 0.55

            shader9 = mem:///root/foo.slang
            scale_type_x9 = viewport
            scale_x9      = 2.5
            scale_type_y9 = source

            # scale

            shader10 = mem:///root/foo.slang
            scale_type10 = absolute
            scale10      = 150

            shader11 = mem:///root/foo.slang
            scale_type11 = source
            scale11      = 0.75

            shader12 = mem:///root/foo.slang
            scale_type12 = viewport
            scale12      = 1.50

            # invalid

            # invalid because it only specifies one axis

            shader13 = mem:///root/foo.slang
            scale_type_x13 = viewport
            scale_x13      = 1.50

            """
        
        InMemProtocol.requests = [
            "mem:///root/foo.slangp": cfg,
            "mem:///root/foo.slang": "#version 450",
        ]
        
        let url = URL(string: "mem:///root/foo.slangp")!
        do {
            let ss = try SlangShader(fromURL: url)
            
            do {
                // test default
                let passes = ss.passes[0...0]
                XCTAssertEqual(passes.compactMap(\.scaleX), [])
                XCTAssertEqual(passes.compactMap(\.scaleY), [])
            }
            
            do {
                // test passes using absolute
                let passes = ss.passes[1...3]
                XCTAssertEqual(passes.compactMap(\.scaleX), [.absolute(size: 0), .absolute(size: 100), .absolute(size: 100)])
                XCTAssertEqual(passes.compactMap(\.scaleY), [.absolute(size: 0), .absolute(size: 200), .source(scale: 1)])
            }
            
            do {
                // test passes using source
                let passes = ss.passes[4...6]
                XCTAssertEqual(passes.compactMap(\.scaleX), [.source(scale: 1), .source(scale: 0.25), .source(scale: 2.5)])
                XCTAssertEqual(passes.compactMap(\.scaleY), [.source(scale: 1), .source(scale: 0.55), .source(scale: 1.0)])
            }
            
            do {
                // test passes using viewport
                let passes = ss.passes[7...9]
                XCTAssertEqual(passes.compactMap(\.scaleX), [.viewport(scale: 1), .viewport(scale: 0.25), .viewport(scale: 2.5)])
                XCTAssertEqual(passes.compactMap(\.scaleY), [.viewport(scale: 1), .viewport(scale: 0.55), .source(scale: 1.0)])
            }

            do {
                // test passes using single scale scalar
                let passes = ss.passes[10...12]
                XCTAssertEqual(passes.compactMap(\.scaleX), [.absolute(size: 150), .source(scale: 0.75), .viewport(scale: 1.50)])
                XCTAssertEqual(passes.compactMap(\.scaleY), [.absolute(size: 150), .source(scale: 0.75), .viewport(scale: 1.50)])
            }

            do {
                // test with invalid scale definitions
                let passes = ss.passes[13...13]
                XCTAssertEqual(passes.compactMap(\.scaleX), [])
                XCTAssertEqual(passes.compactMap(\.scaleY), [])
            }

        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testShaderPassWrap() {
        let cfg =
            """
            shaders = 5

            # shader zero verifies defaults
            shader0 = mem:///root/foo.slang

            shader1 = mem:///root/foo.slang
            wrap_mode1 = clamp_to_border

            shader2 = mem:///root/foo.slang
            wrap_mode2 = clamp_to_edge

            shader3 = mem:///root/foo.slang
            wrap_mode3 = mirrored_repeat

            shader4 = mem:///root/foo.slang
            wrap_mode4 = repeat
            """
        
        InMemProtocol.requests = [
            "mem:///root/foo.slangp": cfg,
            "mem:///root/foo.slang": "#version 450",
        ]
        
        let url = URL(string: "mem:///root/foo.slangp")!
        do {
            let ss = try SlangShader(fromURL: url)
            XCTAssertEqual(ss.passes.map(\.wrapMode), [.border, .border, .edge, .mirroredRepeat, .repeat])
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testShaderPassFormat() {
        let cfg =
            """
            shaders = 5

            # shader zero verifies defaults
            shader0 = mem:///root/foo.slang

            shader1 = mem:///root/foo.slang
            float_framebuffer1 = true

            shader2 = mem:///root/foo.slang
            srgb_framebuffer2 = true

            shader3 = mem:///root/bar.slang

            # verifies #pragma format takes precedence
            shader4 = mem:///root/cat.slang
            srgb_framebuffer4 = true
            """
        
        InMemProtocol.requests = [
            "mem:///root/foo.slangp": cfg,
            "mem:///root/foo.slang": "#version 450",
            "mem:///root/bar.slang": "#version 450\n#pragma format R32_UINT",
            "mem:///root/cat.slang": "#version 450\n#pragma format R16_SINT",
        ]
        
        let url = URL(string: "mem:///root/foo.slangp")!
        do {
            let ss = try SlangShader(fromURL: url)
            XCTAssertEqual(ss.passes.map(\.format), [.bgra8Unorm, .rgba16Float, .bgra8Unorm_srgb, .r32Uint, .r16Sint])
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testShaderPassFilter() {
        let cfg =
            """
            shaders = 3

            # shader zero verifies defaults
            shader0 = mem:///root/foo.slang

            shader1 = mem:///root/foo.slang
            filter_linear1 = false

            shader2 = mem:///root/foo.slang
            filter_linear2 = true
            """
        
        InMemProtocol.requests = [
            "mem:///root/foo.slangp": cfg,
            "mem:///root/foo.slang": "#version 450",
        ]
        
        let url = URL(string: "mem:///root/foo.slangp")!
        do {
            let ss = try SlangShader(fromURL: url)
            XCTAssertEqual(ss.passes.map(\.filter), [.unspecified, .nearest, .linear])
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testShaderLUT() {
        let cfg =
            """
            shaders = 1

            shader0 = mem:///root/foo.slang

            textures = "a;b;c;d;e"
            # defaults
            a = "image_a.png"

            b = "image_b.png"
            b_wrap_mode = "clamp_to_border"
            b_linear    = false
            b_mipmap    = false

            c = "image_c.png"
            c_wrap_mode = "clamp_to_edge"
            c_linear    = true
            c_mipmap    = false

            d = "image_d.png"
            d_wrap_mode = "mirrored_repeat"
            d_linear    = false
            d_mipmap    = true

            e = "image_e.png"
            e_wrap_mode = "repeat"
            e_linear    = true
            e_mipmap    = true
            """
        
        InMemProtocol.requests = [
            "mem:///root/foo.slangp": cfg,
            "mem:///root/foo.slang": "#version 450",
        ]
        
        let url = URL(string: "mem:///root/foo.slangp")!
        do {
            let ss = try SlangShader(fromURL: url)
            let luts = ss.luts.sorted { $0.name < $1.name }
            XCTAssertEqual(luts.map(\.url.lastPathComponent), ["a", "b", "c", "d", "e"].map { "image_\($0).png" })
            XCTAssertEqual(luts.map(\.name), ["a", "b", "c", "d", "e"])
            XCTAssertEqual(luts.map(\.wrapMode), [.border, .border, .edge, .mirroredRepeat, .repeat])
            XCTAssertEqual(luts.map(\.isMipmap), [false, false, false, true, true])
            XCTAssertEqual(luts.map(\.filter), [.unspecified, .nearest, .linear, .nearest, .linear])
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testShaderParameter() {
        let cfg =
            """
            shaders = 1

            shader0 = mem:///root/foo.slang

            parameters = "PARAM1"

            PARAM1 = 0.75

            """
        
        let src =
            """
            #version 450
            #pragma parameter PARAM1 "Param 1" 0.50 0.25 1.00 0.01
            #pragma parameter PARAM2 "Param 2" 1.00 0.00 3.00 1.00
            """
        
        InMemProtocol.requests = [
            "mem:///root/foo.slangp": cfg,
            "mem:///root/foo.slang": src,
        ]
        
        let url = URL(string: "mem:///root/foo.slangp")!
        do {
            let ss = try SlangShader(fromURL: url)
            let params = ss.parameters.sorted { $0.name < $1.name }
            XCTAssertEqual(params.map(\.name), ["PARAM1", "PARAM2"])
            XCTAssertEqual(params.map(\.initial), [0.75, 1.00])
            XCTAssertEqual(params.map(\.minimum), [0.25, 0.00])
            XCTAssertEqual(params.map(\.maximum), [1.00, 3.00])
            XCTAssertEqual(params.map(\.step), [0.01, 1.00])
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testOneFileParametersInConfig() {
        let cfg =
            """
            shaders = 1
            shader0 = mem:///root/foo.slang
            """
        
        let src =
            """
            #version 450

            #pragma name this_is_the_name
            #pragma parameter foo1 "Foo 1 param" 0.5 0.0 1.0 0.01
            #pragma parameter bar1 "Bar 1 param" 0.5 0.0 1.0 0.01
            #pragma parameter foo2 "Foo 2 param" 0.5 0.0 1.0 0.01
            #pragma parameter bar2 "Bar 2 param" 0.5 0.0 1.0 0.01

            #pragma stage vertex
            // vertex
            #pragma stage fragment
            // fragment
            """
        InMemProtocol.requests = [
            "mem:///root/foo.slangp": cfg,
            "mem:///root/foo.slang": src,
        ]
        
        let url = URL(string: "mem:///root/foo.slangp")!
        do {
            let ss = try SlangShader(fromURL: url)
            XCTAssertEqual(ss.passes.count, 1)
            let pass = ss.passes[0]
            XCTAssertEqual(pass.alias, "this_is_the_name")
            
            let exp = ShaderParameter.list(
                Param(name: "foo1", desc: "Foo 1 param"),
                Param(name: "bar1", desc: "Bar 1 param"),
                Param(name: "foo2", desc: "Foo 2 param"),
                Param(name: "bar2", desc: "Bar 2 param"))
            
            let params = ss.parameters
            XCTAssertEqual(params, exp)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}

private extension CGSize {
    static let one = CGSize(width: 1, height: 1)
}
