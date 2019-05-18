//
// Created by Stuart Carnie on 2019-05-06.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#import "ShaderPassSemantics.h"

@implementation ShaderPassUniformBinding

+ (instancetype)makeUniformWithData:(void *)data size:(size_t)size offset:(size_t)offset name:(NSString *)name {
    ShaderPassUniformBinding *u = [self new];
    u.data = data;
    u.size = size;
    u.offset = offset;
    u.name = name;
    return u;
}
@end

@implementation ShaderPassBufferBinding {
    NSMutableArray<ShaderPassUniformBinding *> *_uniforms;
}

- (instancetype)init {
    self = [super init];
    _uniforms = [NSMutableArray new];
    return self;
}

- (ShaderPassUniformBinding *)addUniformData:(void *)data size:(size_t)size offset:(size_t)offset name:(NSString *)name {
    ShaderPassUniformBinding *u = [ShaderPassUniformBinding makeUniformWithData:data size:size offset:offset name:name];
    [_uniforms addObject:u];
    return u;
}
@end

@implementation ShaderPassTextureBinding
+ (instancetype)makeWithTexture:(id <MTLTexture> __unsafe_unretained *)texture {
    ShaderPassTextureBinding *s = [self new];
    s.texture = texture;
    return s;
}
@end


@implementation ShaderPassBindings {
    NSMutableArray<ShaderPassTextureBinding *> *_textures;
    NSArray<ShaderPassBufferBinding *> *_buffers;
}

- (instancetype)init {
    self = [super init];

    _textures = [NSMutableArray new];
    // equivalent to kMaxConstantBuffers
    _buffers = @[[ShaderPassBufferBinding new], [ShaderPassBufferBinding new]];

    return self;
}

- (ShaderPassTextureBinding *)addTexture:(id <MTLTexture> __unsafe_unretained *)texture {
    ShaderPassTextureBinding *t = [ShaderPassTextureBinding makeWithTexture:texture];
    [_textures addObject:t];
    return t;
}

@end

@implementation ShaderPassBufferSemantics {

}
+ (instancetype)makeWithData:(void *)data {
    ShaderPassBufferSemantics *s = [self new];
    s.data = data;
    return s;
}
@end

@implementation ShaderPassTextureSemantics {

}
+ (instancetype)makeWithTexture:(id <MTLTexture> __unsafe_unretained *)texture
                         stride:(size_t)ts
                           size:(void *)size
                         stride:(size_t)ss {
    ShaderPassTextureSemantics *s = [self new];
    s.texture = texture;
    s.textureStride = ts;
    s.textureSize = size;
    s.sizeStride = ss;
    return s;
}
@end

@implementation ShaderPassSemantics {
    NSMutableDictionary<OEShaderTextureSemantic, ShaderPassTextureSemantics *> *_textures;
    NSMutableDictionary<OEShaderBufferSemantic, ShaderPassBufferSemantics *> *_uniforms;
}

- (instancetype)init {
    self = [super init];
    _textures = [NSMutableDictionary<OEShaderTextureSemantic, ShaderPassTextureSemantics *> new];
    _uniforms = [NSMutableDictionary<OEShaderBufferSemantic, ShaderPassBufferSemantics *> new];
    return self;
}

- (void)addTexture:(id <MTLTexture> __unsafe_unretained *)texture
            stride:(size_t)ts
              size:(void *)size
            stride:(size_t)ss
          semantic:(OEShaderTextureSemantic)semantic {
    _textures[semantic] = [ShaderPassTextureSemantics makeWithTexture:texture stride:ts size:size stride:ss];
}

- (void)addUniformData:(void *)data semantic:(OEShaderBufferSemantic)semantic {
    _uniforms[semantic] = [ShaderPassBufferSemantics makeWithData:data];
}
@end
