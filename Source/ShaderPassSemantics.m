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

#import "ShaderPassSemantics.h"

@implementation ShaderPassUniformBinding

+ (instancetype)makeUniformWithData:(void *)data size:(size_t)size offset:(size_t)offset name:(NSString *)name
{
    ShaderPassUniformBinding *u = [self new];
    u.data   = data;
    u.size   = size;
    u.offset = offset;
    u.name   = name;
    return u;
}
@end

@implementation ShaderPassBufferBinding
{
    NSMutableArray<ShaderPassUniformBinding *> *_uniforms;
}

- (instancetype)init
{
    self      = [super init];
    _uniforms = [NSMutableArray new];
    return self;
}

- (ShaderPassUniformBinding *)addUniformData:(void *)data size:(size_t)size offset:(size_t)offset name:(NSString *)name
{
    ShaderPassUniformBinding *u = [ShaderPassUniformBinding makeUniformWithData:data size:size offset:offset name:name];
    [_uniforms addObject:u];
    return u;
}
@end

@implementation ShaderPassTextureBinding
+ (instancetype)makeWithTexture:(id<MTLTexture> __unsafe_unretained *)texture
{
    ShaderPassTextureBinding *s = [self new];
    s.texture = texture;
    return s;
}
@end


@implementation ShaderPassBindings
{
    NSMutableArray<ShaderPassTextureBinding *> *_textures;
    NSArray<ShaderPassBufferBinding *>         *_buffers;
}

- (instancetype)init
{
    self = [super init];
    
    _textures = [NSMutableArray new];
    // equivalent to kMaxConstantBuffers
    _buffers  = @[[ShaderPassBufferBinding new], [ShaderPassBufferBinding new]];
    
    return self;
}

- (ShaderPassTextureBinding *)addTexture:(id<MTLTexture> __unsafe_unretained *)texture
{
    ShaderPassTextureBinding *t = [ShaderPassTextureBinding makeWithTexture:texture];
    [_textures addObject:t];
    return t;
}

@end

@implementation ShaderPassBufferSemantics

+ (instancetype)makeWithData:(void *)data
{
    ShaderPassBufferSemantics *s = [self new];
    s.data = data;
    return s;
}
@end

@implementation ShaderPassTextureSemantics

+ (instancetype)makeWithTexture:(id<MTLTexture> __unsafe_unretained *)texture
                         stride:(size_t)ts
                           size:(void *)size
                         stride:(size_t)ss
{
    ShaderPassTextureSemantics *s = [self new];
    s.texture       = texture;
    s.textureStride = ts;
    s.textureSize   = size;
    s.sizeStride    = ss;
    return s;
}
@end

@implementation ShaderPassSemantics
{
    NSMutableDictionary<OEShaderTextureSemantic, ShaderPassTextureSemantics *> *_textures;
    NSMutableDictionary<OEShaderBufferSemantic, ShaderPassBufferSemantics *>   *_uniforms;
}

- (instancetype)init
{
    self      = [super init];
    _textures = [NSMutableDictionary<OEShaderTextureSemantic, ShaderPassTextureSemantics *> new];
    _uniforms = [NSMutableDictionary<OEShaderBufferSemantic, ShaderPassBufferSemantics *> new];
    return self;
}

- (void)addTexture:(id<MTLTexture> __unsafe_unretained *)texture
            stride:(size_t)ts
              size:(void *)size
            stride:(size_t)ss
          semantic:(OEShaderTextureSemantic)semantic
{
    _textures[semantic] = [ShaderPassTextureSemantics makeWithTexture:texture stride:ts size:size stride:ss];
}

- (void)addUniformData:(void *)data semantic:(OEShaderBufferSemantic)semantic
{
    _uniforms[semantic] = [ShaderPassBufferSemantics makeWithData:data];
}
@end
