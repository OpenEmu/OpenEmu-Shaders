//
//  ConfigTests.swift
//  OpenEmuShaders
//
//  Created by Stuart Carnie on 2019-05-16.
//  Copyright © 2019 OpenEmu. All rights reserved.
//

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

        scanning:
        while true {
            switch c.scan() {
            case .keyval(let (key, val)):
                print("\(key): \(val)")
            case .eof:
                print("eof")
                break scanning
            }
        }

    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
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

            for _ in 0..<1000 {
                c.reset()

                scanning:
                while true {
                    switch c.scan() {
                    case .keyval:
                        break;
                    case .eof:
                        break scanning
                    }
                }

            }
        }
    }
}

class ShaderConfigSerializationTests: XCTestCase {
    func testSlang() {
        let url = URL(fileURLWithPath: "/Volumes/Data/projects/libretro/slang-shaders/crt/phosphorlut.slangp")
        do {
            let res = try ShaderConfigSerialization.config(fromURL: url)
            print(res)
        } catch {
            XCTFail("unexpected error: \(error.localizedDescription)")
        }

    }

    func testSlangFromString() {
        let s = """
                shaders = 2
                shader0 = ../foo.slang

                shader1 = shaders/bar.slang
                """
        do {
            let res = try ShaderConfigSerialization.parseConfig(ShaderConfigSerializationTests.phosphorlut)
            print(res)
        } catch {
            XCTFail("unexpected error: \(error.localizedDescription)")
        }
    }

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