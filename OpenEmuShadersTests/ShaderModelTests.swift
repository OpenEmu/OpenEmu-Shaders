//
//  ShaderModel.swift
//  OpenEmuShadersTests
//
//  Created by Stuart Carnie on 5/9/20.
//  Copyright © 2020 OpenEmu. All rights reserved.
//

import XCTest

@testable import OpenEmuShaders

class ShaderModelTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let d = """
        shaders = 1

        shader0     = "foo"
        alias0      = firstPass
        scale_type0 = absolute
        scale_x0    = 100
        scale_y0    = 200

        textures         = "shadow"
        shadow           = "some/path.png"
        shadow_wrap_mode = clamp_to_border
        """
        do {
            let model = try ShaderConfigSerialization.makeShaderModel(from: d)
            XCTAssertEqual(model.passes.count, 1)
        } catch {
            XCTFail("unexpected failure: \(error)")
        }
    }
}
