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

class ConfigScannerTests: XCTestCase {
    func testConfigScan() {
        var c = ConfigScanner(
            """
            shaders = 5

            # this is a comment

            shader0 = "foo"
            alias0  = firstPass
            alias1  = ../this/and/that.foo
            scale0  = 2.0
            type0   = hi_there # remaining comment
            type1   = "hello there" # remaining comment

            type2   = "hello #ignore this there" # remaining comment

            shadow_linear = clamp_to_border
            """)
        
        let expected = [
            ("shaders", "5"),
            ("shader0", "foo"),
            ("alias0", "firstPass"),
            ("alias1", "../this/and/that.foo"),
            ("scale0", "2.0"),
            ("type0", "hi_there"),
            ("type1", "hello there"),
            ("type2", "hello #ignore this there"),
            ("shadow_linear", "clamp_to_border"),
        ]
        
        for (expKey, expVal) in expected {
            switch c.scan() {
            case .keyval(let key, let val):
                XCTAssertEqual(key, expKey, "unexpected key")
                XCTAssertEqual(val, expVal, "unexpected value")
            case .eof:
                XCTFail("unexpected .eof")
            }
        }
    }
    
    @available(OSX 10.15, *)
    func testPerformanceExample() {
        measure(metrics: [XCTCPUMetric(limitingToCurrentThread: true), XCTClockMetric()]) {
            var c = ConfigScanner(
                """
                shaders = 5

                # this is a comment

                shader0 = "foo"
                alias0  = firstPass
                alias1  = ../this/and/that.foo
                scale0  = 2.0
                type0   = hi_there # remaining comment
                type1   = "hello there" # remaining comment

                type2   = "hello #ignore this there" # remaining comment
                """)
            
            scanning:
                while true
            {
                switch c.scan() {
                case .keyval:
                    continue
                case .eof:
                    break scanning
                }
            }
        }
    }
}

class ShaderConfigSerializationTests: XCTestCase {
    func testSlangFromString() {
        do {
            let res = try ShaderConfigSerialization.makeShaderModel(from: Self.phosphorlut)
            print(res)
        } catch {
            XCTFail("unexpected error: \(error.localizedDescription)")
        }
    }
    
    // swiftlint:disable line_length
    static let phosphorlut =
        """
        shaders = 5

        shader0 = shaders/phosphorlut/scanlines-interlace-linearize.slang
        alias0 = firstPass
        scale0 = 2.0
        scale_type0 = source
        srgb_framebuffer0 = true
        filter_linear0 = false

        shader1 = ../blurs/blur5fast-vertical.slang
        scale_type1 = source
        scale1 = 1.0
        srgb_framebuffer1 = true
        filter_linear1 = true
        alias1 = blurPassV

        shader2 = ../blurs/blur5fast-horizontal.slang
        alias2 = blurPass
        filter_linear2 = true
        scale2 = 1.0
        scale_type2 = source
        srgb_framebuffer2 = true

        shader3 = shaders/phosphorlut/phosphorlut-pass0.slang
        alias3 = phosphorPass
        filter_linear3 = true
        scale_type3 = source
        scale_x3 = 4.0
        scale_y3 = 2.0
        srgb_framebuffer3 = true

        shader4 = shaders/phosphorlut/phosphorlut-pass1.slang
        filter_linear4 = true

        textures = "shadow;aperture;slot"
        shadow = shaders/phosphorlut/luts/shadowmask.png
        shadow_linear = true
        shadow_wrap_mode = "repeat"
        aperture = shaders/phosphorlut/luts/aperture-grille.png
        aperture_linear = true
        aperture_wrap_mode = "repeat"
        slot = shaders/phosphorlut/luts/slotmask.png
        slot_linear = true
        slot_wrap_mode = "repeat"

        parameters = box_scale;location;in_res_x;in_res_y;TVOUT_RESOLUTION;TVOUT_COMPOSITE_CONNECTION;TVOUT_TV_COLOR_LEVELS;enable_480i;top_field_first
        box_scale = 2.000000
        location = 0.500000
        in_res_x = 240.000000
        in_res_y = 160.000000
        TVOUT_RESOLUTION = 512.000000
        TVOUT_COMPOSITE_CONNECTION = 0.000000
        TVOUT_TV_COLOR_LEVELS = 1.000000
        enable_480i = 1.000000
        top_field_first = 1.000000
        """
}
