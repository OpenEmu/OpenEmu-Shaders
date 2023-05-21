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

class NSScannerTests: XCTestCase {
    @available(macOS 10.15, *)
    func testScanQuotedString() {
        let scan = Scanner(string: #"3.0 "hello there" YES"#)
        let f = scan.scanDouble() ?? 0
        XCTAssertEqual(f, 3.0)

        let s = scan.scanQuotedString()
        XCTAssertEqual(s, "hello there")

        let tmp = scan.scanCharacters(from: .alphanumerics)
        XCTAssertEqual(tmp, "YES")
    }
    
    @available(macOS 10.15, *)
    func testScanLineBug1() {
        let s = Scanner(string: "HSM_CRT_EMPTY_LINE\t\t\t\t\t\t\t\"  \" 0 0 0.001 0.001")
        
        let name = s.scanCharacters(from: .identifierCharacters)
        XCTAssertEqual(name, "HSM_CRT_EMPTY_LINE")
        let desc = s.scanQuotedString()
        XCTAssertEqual(desc, "")
    }
}
