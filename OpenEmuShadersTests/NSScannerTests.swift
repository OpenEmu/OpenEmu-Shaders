//
//  NSScannerTests.swift
//  OpenEmuShaders
//
//  Created by Stuart Carnie on 2019-05-16.
//  Copyright © 2019 OpenEmu. All rights reserved.
//

import XCTest

@testable import OpenEmuShaders

class NSScannerTests: XCTestCase {

    func testScanQuotedString() {
        let scan = Scanner(string: "3.0 \"hello there\" YES")
        var f: Double = 0;
        XCTAssertTrue(scan.scanDouble(&f));
        XCTAssertEqual(f, 3.0);

        let s = scan.scanQuotedString()
        XCTAssertEqual(s, "hello there")

        var tmp: NSString?
        XCTAssertTrue(scan.scanCharacters(from: .alphanumerics, into: &tmp))
        XCTAssertEqual(tmp as String?, "YES")
    }
}
