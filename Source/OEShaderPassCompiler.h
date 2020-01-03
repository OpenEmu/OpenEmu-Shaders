//
// Created by Stuart Carnie on 2019-05-17.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@class SlangShader;
@class ShaderPassSemantics;
@class ShaderPassBindings;

@interface OEShaderPassCompiler : NSObject
- (instancetype)initWithShaderModel:(SlangShader *)shader;

- (BOOL)buildPass:(NSUInteger)passNumber
     metalVersion:(MTLLanguageVersion)metalVersion
    passSemantics:(ShaderPassSemantics *)passSemantics
     passBindings:(ShaderPassBindings *)passBindings
           vertex:(NSString **)vsrc
         fragment:(NSString **)fsrc;

@end
