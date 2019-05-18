//
//  OESourceParserTests.swift
//  OpenEmuShadersTests
//
//  Created by Stuart Carnie on 5/15/19.
//  Copyright © 2019 OpenEmu. All rights reserved.
//

import XCTest

@testable import OpenEmuShaders

class OESourceParserTests: XCTestCase {
    override func setUp() {
        InMemProtocol.requests = [:]
    }
    
    func testSourceParser() {
        let lines = [
            """
        #version 450
        // header source
        ""","""
        #pragma stage vertex
        // vertex source
        ""","""
        #pragma stage fragment
        // fragment source
        """,
        ]
        
        let expected = [
            """
            #version 450
            #extension GL_GOOGLE_cpp_style_line_directive : require
            #line 2 ""
            // header source
            #line 4 ""
            // vertex source
            ""","""
            #version 450
            #extension GL_GOOGLE_cpp_style_line_directive : require
            #line 2 ""
            // header source
            #line 6 ""
            // fragment source
            """,
        ]
        
        InMemProtocol.requests["mem://foo.slang"] = lines.joined(separator: "\n")
        
        do {
            let url = URL(string: "mem://foo.slang")!
            let p = try OESourceParser(fromURL: url)
            
            XCTAssertEqual(p.vertexSource, expected[0])
            XCTAssertEqual(p.fragmentSource, expected[1])
        } catch {
            XCTFail("unexpected error: \(error.localizedDescription)")
        }
    }
    
    func testSourceParserPragmas() {
        let src = """
        #version 450

        #pragma name this_is_the_name
        #pragma parameter FrameColor_R "Frame Color R" 0.2 0.4 0.6 1.0
        #pragma format R8_UNORM
        
        #pragma stage vertex
        // vertex
        #pragma stage fragment
        // fragment
        """
        
        InMemProtocol.requests["mem://foo.slang"] = src
        
        do {
            let url = URL(string: "mem://foo.slang")!
            let p = try OESourceParser(fromURL: url)
            XCTAssertEqual(p.name, "this_is_the_name")
            XCTAssertEqual(p.format, SlangFormat.r8Unorm)
            let pp = p.parameters["FrameColor_R"]
            XCTAssertNotNil(pp)
            
            let p1 = pp!
            let p2 = OEShaderParameter(name: "FrameColor_R")
            p2.desc = "Frame Color R"
            p2.initial = 0.2
            p2.minimum = 0.4
            p2.maximum = 0.6
            p2.step    = 1.0
            XCTAssertEqual(p1, p2)
        } catch {
            XCTFail("unexpected error: \(error.localizedDescription)")
        }
    }
    
    func testSourceParserInclude() {
        let src = """
        #version 450

        #include "file1.inc"

        #pragma name this_is_the_name
        
        #pragma stage vertex
        // vertex
        #include "file2.inc"
        #pragma stage fragment
        // fragment
        #include "file3.inc"
        """
        InMemProtocol.requests = [
            "mem:///root/foo.slang": src,
            "mem:///root/file1.inc": "// this is\n// file one",
            "mem:///root/file2.inc": "// this is\n// file two",
            "mem:///root/file3.inc": "// this is\n// file three",
        ]
        
        let expected = ["""
        #version 450
        #extension GL_GOOGLE_cpp_style_line_directive : require
        #line 2 "foo.slang"

        #line 1 "file1.inc"
        // this is
        // file one
        #line 3 "foo.slang"

        #line 6 "foo.slang"

        #line 8 "foo.slang"
        // vertex
        #line 1 "file2.inc"
        // this is
        // file two
        #line 9 "foo.slang"
        ""","""
        #version 450
        #extension GL_GOOGLE_cpp_style_line_directive : require
        #line 2 "foo.slang"

        #line 1 "file1.inc"
        // this is
        // file one
        #line 3 "foo.slang"

        #line 6 "foo.slang"

        #line 11 "foo.slang"
        // fragment
        #line 1 "file3.inc"
        // this is
        // file three
        #line 12 "foo.slang"
        """
        ]
        
        do {
            let url = URL(string: "mem:///root/foo.slang")!
            let p = try OESourceParser(fromURL: url)
            XCTAssertEqual(p.name, "this_is_the_name")
            XCTAssertEqual(p.vertexSource, expected[0])
            XCTAssertEqual(p.fragmentSource, expected[1])
        } catch {
            XCTFail("unexpected error: \(error.localizedDescription)")
        }
    }
}
