//
// Created by Stuart Carnie on 2019-05-17.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

@import Foundation;
@import Metal;

NS_ASSUME_NONNULL_BEGIN

@class SlangShader;
@class ShaderPassSemantics;
@class ShaderPassBindings;
@class ShaderCompilerOptions;

@interface OEShaderPassCompiler : NSObject

@property (nonatomic, readonly) NSUInteger                      historyCount;
@property (nonatomic, readonly) NSArray<ShaderPassBindings *>  *bindings;

- (instancetype)initWithShaderModel:(SlangShader *)shader;

- (BOOL)buildPass:(NSUInteger)passNumber
          options:(ShaderCompilerOptions *)options
    passSemantics:(ShaderPassSemantics * _Nullable)passSemantics
           vertex:(NSString * _Nullable * _Nonnull)vsrc
         fragment:(NSString * _Nullable * _Nonnull)fsrc
            error:(NSError * _Nullable * _Nullable)error NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
