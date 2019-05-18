//
// Created by Stuart Carnie on 2019-05-07.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

@import Foundation;
#import "SlangShader.h"
#import "ShaderPassSemantics.h"

@interface ShaderTextureSemanticMeta : NSObject
@property (nonatomic) NSUInteger binding;
@property (nonatomic) NSUInteger uboOffset;
@property (nonatomic) NSUInteger pushOffset;
@property (nonatomic) OEStageUsage stageUsage;
@property (nonatomic) BOOL texture;
@property (nonatomic) BOOL uboActive;
@property (nonatomic) BOOL pushActive;
@end

@interface ShaderSemanticMeta : NSObject
@property (nonatomic) NSUInteger uboOffset;
@property (nonatomic) NSUInteger pushOffset;
@property (nonatomic) NSUInteger numberOfComponents;
@property (nonatomic) BOOL uboActive;
@property (nonatomic) BOOL pushActive;
@end

@interface ShaderTextureSemanticMap : NSObject
@property (nonatomic) OEShaderTextureSemantic semantic;
@property (nonatomic) NSUInteger index;
@end

@interface ShaderSemanticMap : NSObject
@property (nonatomic) OEShaderBufferSemantic semantic;
@property (nonatomic) NSUInteger index;
@end

@interface ShaderReflection : NSObject

@property (nonatomic) NSUInteger passNumber;
@property (nonatomic) size_t uboSize;
@property (nonatomic) size_t pushSize;
@property (nonatomic) NSUInteger uboBinding;
@property (nonatomic) OEStageUsage uboStageUsage;
@property (nonatomic) OEStageUsage pushStageUsage;
@property (nonatomic, readonly) NSDictionary<OEShaderTextureSemantic, NSMutableArray<ShaderTextureSemanticMeta *> *> *textures;
@property (nonatomic, readonly) NSDictionary<OEShaderBufferSemantic, ShaderSemanticMeta *> *semantics;
@property (nonatomic, readonly) NSArray<ShaderSemanticMeta *> *floatParameters;

// aliases
@property (nonatomic, readonly) NSDictionary<NSString *, ShaderTextureSemanticMap *> *textureSemanticMap;
@property (nonatomic, readonly) NSDictionary<NSString *, ShaderTextureSemanticMap *> *textureUniformSemanticMap;
@property (nonatomic, readonly) NSDictionary<NSString *, ShaderSemanticMap *> *semanticMap;

- (BOOL)addTextureSemantic:(OEShaderTextureSemantic)semantic passIndex:(NSUInteger)i name:(NSString *)name;
- (BOOL)addTextureBufferSemantic:(OEShaderTextureSemantic)semantic passIndex:(NSUInteger)i name:(NSString *)name;
- (BOOL)addBufferSemantic:(OEShaderBufferSemantic)semantic passIndex:(NSUInteger)i name:(NSString *)name;

- (NSString *)nameForBufferSemantic:(OEShaderBufferSemantic)semantic index:(NSUInteger)index;
- (NSString *)nameForTextureSemantic:(OEShaderTextureSemantic)semantic index:(NSUInteger)index;
- (NSString *)sizeNameForTextureSemantic:(OEShaderTextureSemantic)semantic index:(NSUInteger)index;
- (ShaderSemanticMap *)bufferSemanticForUniformName:(NSString *)name;
- (ShaderTextureSemanticMap *)textureSemanticForUniformName:(NSString *)name;
- (ShaderTextureSemanticMap *)textureSemanticForName:(NSString *)name;

- (BOOL)setOffset:(size_t)offset vecSize:(unsigned)vecSize forFloatParameterAtIndex:(NSUInteger)index ubo:(BOOL)ubo;
- (BOOL)setOffset:(size_t)offset vecSize:(unsigned)vecSize forSemantic:(OEShaderBufferSemantic)semantic ubo:(BOOL)ubo;
- (BOOL)setOffset:(size_t)offset forTextureSemantic:(OEShaderTextureSemantic)semantic atIndex:(NSUInteger)index ubo:(BOOL)ubo;
- (BOOL)setBinding:(NSUInteger)binding forTextureSemantic:(OEShaderTextureSemantic)semantic atIndex:(NSUInteger)index;

@end
