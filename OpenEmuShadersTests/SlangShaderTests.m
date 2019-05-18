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

#import <XCTest/XCTest.h>
#import "SlangShader.h"
#import <OpenEmuShaders/OpenEmuShaders-Swift.h>

@interface SlangShaderTests : XCTestCase

@end

@implementation SlangShaderTests

- (void)testExample {
    OEShaderParameter *p1 = [[OEShaderParameter alloc] initWithName:@"foo" desc: @""];
    OEShaderParameter *p2 = [[OEShaderParameter alloc] initWithName:@"foo2" desc: @""];
    XCTAssertFalse([p1 isEqual:p2]);
    
    NSURL *url = [NSURL fileURLWithPath:@"/Volumes/Data/projects/libretro/slang-shaders/crt/phosphorlut.slangp"];

    NSError *err;
    SlangShader *r = [[SlangShader alloc] initFromURL:url error:&err];
    ShaderPassSemantics *sem = [ShaderPassSemantics new];
    ShaderPassBindings *bind = [ShaderPassBindings new];

    NSString *vs;
    NSString *fs;
    [r buildPass:0 metalVersion:20000 passSemantics:sem passBindings:bind vertex:&vs fragment:&fs];
    [r buildPass:1 metalVersion:20000 passSemantics:sem passBindings:bind vertex:&vs fragment:&fs];
    [r buildPass:2 metalVersion:20000 passSemantics:sem passBindings:bind vertex:&vs fragment:&fs];
    [r buildPass:3 metalVersion:20000 passSemantics:sem passBindings:bind vertex:&vs fragment:&fs];
    [r buildPass:4 metalVersion:20000 passSemantics:sem passBindings:bind vertex:&vs fragment:&fs];
}

@end
