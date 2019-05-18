//
//  OpenEmuShadersTests.m
//  OpenEmuShadersTests
//
//  Created by Stuart Carnie on 5/3/19.
//  Copyright © 2019 OpenEmu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SlangShader.h"
#import <OpenEmuShaders/OpenEmuShaders-Swift.h>

@class OEShaderSpec;

@interface SlangShaderTests : XCTestCase

@end

@implementation SlangShaderTests

- (void)setUp {
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}


- (void)testExample {
    OEShaderSpec *s = [OEShaderSpec new];
    OEShaderParameter *p1 = [[OEShaderParameter alloc] initWithName:@"foo"];
    OEShaderParameter *p2 = [[OEShaderParameter alloc] initWithName:@"foo2"];
    XCTAssertFalse([p1 isEqual:p2]);
    
    NSURL *url = [NSURL fileURLWithPath:@"/Volumes/Data/projects/libretro/slang-shaders/crt/phosphorlut.slangp"];

    NSError *err;
    NSDictionary<NSString *, id> *cfg = [ShaderConfigSerialization configFromURL:url error:&err];

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

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
