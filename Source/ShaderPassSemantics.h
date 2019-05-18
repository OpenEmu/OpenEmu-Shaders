//
// Created by Stuart Carnie on 2019-05-06.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OEEnums.h"

@import Metal;

@interface ShaderPassUniformBinding : NSObject
@property (nonatomic) void *data;
@property (nonatomic) size_t size;
@property (nonatomic) size_t offset;
@property (nonatomic) NSString *name;
@end

@interface ShaderPassBufferBinding : NSObject
@property (nonatomic) OEStageUsage stageUsage;
@property (nonatomic) NSUInteger binding;
@property (nonatomic) size_t size;
@property (nonatomic, readonly) NSArray<ShaderPassUniformBinding *> *uniforms;

- (ShaderPassUniformBinding *)addUniformData:(void *)data size:(size_t)size offset:(size_t)offset name:(NSString *)name;
@end

@interface ShaderPassTextureBinding : NSObject
@property (nonatomic) id<MTLTexture> __unsafe_unretained *texture;
@property (nonatomic) OEShaderPassWrap wrap;
@property (nonatomic) OEShaderPassFilter filter;
@property (nonatomic) OEStageUsage stageUsage;
@property (nonatomic) NSUInteger binding;
@property (nonatomic) NSString *name;

@end

@interface ShaderPassBindings : NSObject
@property (nonatomic) SlangFormat format;
@property (nonatomic, readonly) NSArray<ShaderPassBufferBinding *> *buffers;
@property (nonatomic, readonly) NSArray<ShaderPassTextureBinding *> *textures;

- (ShaderPassTextureBinding *)addTexture:(id<MTLTexture> __unsafe_unretained *)texture;

@end

@interface ShaderPassBufferSemantics : NSObject
@property (nonatomic) void *data;
@end

@interface ShaderPassTextureSemantics : NSObject
@property (nonatomic) id<MTLTexture> __unsafe_unretained *texture;
@property (nonatomic) size_t textureStride;
@property (nonatomic) void *textureSize;
@property (nonatomic) size_t sizeStride;
@end

@interface ShaderPassSemantics : NSObject

@property (nonatomic, readonly) NSDictionary<OEShaderTextureSemantic, ShaderPassTextureSemantics *> *textures;
@property (nonatomic, readonly) NSDictionary<OEShaderBufferSemantic, ShaderPassBufferSemantics *> *uniforms;

- (void)addTexture:(id<MTLTexture> __unsafe_unretained *)texture
            stride:(size_t)ts
              size:(void *)size
            stride:(size_t)ss
          semantic:(OEShaderTextureSemantic)semantic;

- (void)addUniformData:(void *)data semantic:(OEShaderBufferSemantic)semantic;
@end
