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
