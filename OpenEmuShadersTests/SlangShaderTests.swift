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
        let cfg = """
shaders = 0
"""
        InMemProtocol.requests = [
            "mem:///root/foo.slangp": cfg,
        ]
        
        let url = URL(string: "mem:///root/foo.slangp")!
        do {
            let ss = try SlangShader(from: url)
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
frame_count_mod0 = 2
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
            let ss = try SlangShader(from: url)
            XCTAssertEqual(ss.passes.count, 1)
            XCTAssertEqual(ss.passes[0].alias, "this_is_the_name")
            XCTAssertEqual(ss.passes[0].frameCountMod, 2)
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
            let ss = try SlangShader(from: url)
            XCTAssertEqual(ss.passes.count, 1)
            
            let pass = ss.passes[0]
            XCTAssertEqual(pass.url, URL(string: "mem:///root/foo.slang")!)
            XCTAssertEqual(pass.frameCountMod, 0)
            XCTAssertEqual(pass.scaleX, .invalid)
            XCTAssertEqual(pass.scaleY, .invalid)
            XCTAssertEqual(pass.format, .bgra8Unorm)
            XCTAssertEqual(pass.filter, .unspecified)
            XCTAssertEqual(pass.wrapMode, .default)
            XCTAssertEqual(pass.scale, .zero)
            XCTAssertEqual(pass.size, .zero)
            XCTAssertFalse(pass.isScaled)
            XCTAssertFalse(pass.isFloat)
            XCTAssertFalse(pass.issRGB)
            XCTAssertFalse(pass.isMipmap)
            XCTAssertFalse(pass.isFeedback)
            XCTAssertTrue(pass.alias.isEmpty)
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
            let ss = try SlangShader(from: url)
            XCTAssertEqual(ss.passes.map(\.frameCountMod), [0, 1, 100])
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testShaderPassScale() {
        let cfg =
        """
shaders = 10

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

"""
        
        InMemProtocol.requests = [
            "mem:///root/foo.slangp": cfg,
            "mem:///root/foo.slang": "#version 450",
        ]
        
        let url = URL(string: "mem:///root/foo.slangp")!
        do {
            let ss = try SlangShader(from: url)
            
            do {
                // test default
                let passes = ss.passes[0...0]
                XCTAssertEqual(passes.map(\.scaleX), [.invalid])
                XCTAssertEqual(passes.map(\.scaleY), [.invalid])
                XCTAssertEqual(passes.map(\.scale), [.zero])
                XCTAssertEqual(passes.map(\.size), [.zero])
            }
            
            do {
                // test passes using absolute
                let passes = ss.passes[1...3]
                XCTAssertEqual(passes.map(\.scaleX), [.absolute, .absolute, .absolute])
                XCTAssertEqual(passes.map(\.scaleY), [.absolute, .absolute, .source])
                XCTAssertEqual(passes.map(\.scale), [.one, .one, .one])
                XCTAssertEqual(passes.map(\.size), [.zero, CGSize(width: 100, height: 200), CGSize(width: 100, height: 0)])
            }
            
            do {
                // test passes using source
                let passes = ss.passes[4...6]
                XCTAssertEqual(passes.map(\.scaleX), [.source, .source, .source])
                XCTAssertEqual(passes.map(\.scaleY), [.source, .source, .source])
                XCTAssertEqual(passes.map(\.scale), [.one, CGSize(width: 0.25, height: 0.55), CGSize(width: 2.5, height: 1)])
                XCTAssertEqual(passes.map(\.size), [.zero, .zero, .zero])
            }
            
            do {
                // test passes using viewport
                let passes = ss.passes[7...9]
                XCTAssertEqual(passes.map(\.scaleX), [.viewport, .viewport, .viewport])
                XCTAssertEqual(passes.map(\.scaleY), [.viewport, .viewport, .source])
                XCTAssertEqual(passes.map(\.scale), [.one, CGSize(width: 0.25, height: 0.55), CGSize(width: 2.5, height: 1)])
                XCTAssertEqual(passes.map(\.size), [.zero, .zero, .zero])
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
            let ss = try SlangShader(from: url)
            XCTAssertEqual(ss.passes.map(\.wrapMode), [.default, .border, .edge, .mirroredRepeat, .repeat])
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testOneFileParametersGroupsInConfig() {
        let cfg =
        """
shaders = 1
shader0 = mem:///root/foo.slang

parameter_groups = "foo;bar"
foo_group_desc = "Foo group"
foo_group_parameters = "foo1;foo2"
bar_group_desc = "Bar group"
bar_group_parameters = "bar2;bar1"
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
            let ss = try SlangShader(from: url)
            XCTAssertEqual(ss.passes.count, 1)
            let pass = ss.passes[0]
            XCTAssertEqual(pass.alias, "this_is_the_name")
            
            let groups = ss.parameterGroups
            XCTAssertEqual(groups.count, 3)
            
            let exp = ShaderParameter.list(
                Param(name: "foo1", desc: "Foo 1 param", group: "Foo Group"),
                Param(name: "foo2", desc: "Foo 2 param", group: "Foo Group"),
                Param(name: "bar2", desc: "Bar 2 param", group: "Bar Group"),
                Param(name: "bar1", desc: "Bar 1 param", group: "Bar Group")
            )
            
            let params = ss.parameters
            XCTAssertEqual(params, exp)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    
    func testOneFileParametersGroupsInConfigWithDefaultOverride() {
        let cfg =
        """
shaders = 1
shader0 = mem:///root/foo.slang

parameter_groups = "foo;default"
foo_group_desc = "Foo group"
foo_group_parameters = "foo1;foo2"
default_group_desc = "Other parameters"
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
            let ss = try SlangShader(from: url)
            XCTAssertEqual(ss.passes.count, 1)
            let pass = ss.passes[0]
            XCTAssertEqual(pass.alias, "this_is_the_name")
            
            let groups = ss.parameterGroups
            XCTAssertEqual(groups.count, 2)
            
            let exp = ShaderParameter.list(
                Param(name: "foo1", desc: "Foo 1 param", group: "Foo Group"),
                Param(name: "foo2", desc: "Foo 2 param", group: "Foo Group"),
                Param(name: "bar1", desc: "Bar 1 param", group: "Other parameters"),
                Param(name: "bar2", desc: "Bar 2 param", group: "Other parameters")
            )
            
            let params = ss.parameters
            XCTAssertEqual(params, exp)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
}

extension CGSize {
    static let one = CGSize(width: 1, height: 1)
}
