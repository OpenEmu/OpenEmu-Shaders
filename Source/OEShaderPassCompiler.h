//
// Created by Stuart Carnie on 2019-05-17.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SlangShader;
@class ShaderPassSemantics;
@class ShaderPassBindings;

@interface OEShaderPassCompiler : NSObject
- (instancetype)initWithShaderModel:(SlangShader *)shader;

- (BOOL)buildPass:(NSUInteger)passNumber
     metalVersion:(NSUInteger)version
    passSemantics:(ShaderPassSemantics *)passSemantics
     passBindings:(ShaderPassBindings *)passBindings
           vertex:(NSString **)vsrc
         fragment:(NSString **)fsrc;

@end