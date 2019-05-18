//
//  OEShaderSpecTests.swift
//  OpenEmuShadersTests
//
//  Created by Stuart Carnie on 5/11/19.
//  Copyright © 2019 OpenEmu. All rights reserved.
//

import Foundation
import XCTest

@testable import OpenEmuShaders

class OEShaderSpecTests : XCTestCase {
    func testFoo() {
        let data = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>passes</key>
    <array>
    </array>
    <key>sem</key>
    <string>foo</string>
</dict>
</plist>
""".data(using: .utf8)!
        
        let decoder = PropertyListDecoder()
        let s = try! decoder.decode(OEShaderSpec.self, from: data)
        print(s.passes)
    }
}
