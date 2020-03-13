//
// Created by Stuart Carnie on 2019-05-17.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@class SlangShader;
@class ShaderPassSemantics;
@class ShaderPassBindings;

@interface OEShaderPassCompiler : NSObject
- (instancetype)initWithShaderModel:(SlangShader *)shader;

- (BOOL)buildPass:(NSUInteger)passNumber
     metalVersion:(MTLLanguageVersion)metalVersion
    passSemantics:(ShaderPassSemantics *)passSemantics
     passBindings:(ShaderPassBindings *)passBindings
           vertex:(NSString * _Nullable * _Nonnull)vsrc
         fragment:(NSString * _Nullable * _Nonnull)fsrc
            error:(NSError * _Nullable *)error;

@end

NS_ASSUME_NONNULL_END
