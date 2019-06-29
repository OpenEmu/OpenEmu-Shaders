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

#import <Foundation/Foundation.h>
#import "OEEnums.h"

@import Metal;

@interface ShaderPassUniformBinding : NSObject
@property (nonatomic) void     *data;
@property (nonatomic) size_t   size;
@property (nonatomic) size_t   offset;
@property (nonatomic) NSString *name;
@end

@interface ShaderPassBufferBinding : NSObject
@property (nonatomic) OEStageUsage                                  stageUsage;
@property (nonatomic) NSUInteger                                    bindingVert;
@property (nonatomic) NSUInteger                                    bindingFrag;
@property (nonatomic) size_t                                        size;
@property (nonatomic, readonly) NSArray<ShaderPassUniformBinding *> *uniforms;

- (ShaderPassUniformBinding *)addUniformData:(void *)data size:(size_t)size offset:(size_t)offset name:(NSString *)name;
@end

@interface ShaderPassTextureBinding : NSObject
@property (nonatomic) id<MTLTexture> __unsafe_unretained *texture;
@property (nonatomic) OEShaderPassWrap                   wrap;
@property (nonatomic) OEShaderPassFilter                 filter;
@property (nonatomic) OEStageUsage                       stageUsage;
@property (nonatomic) NSUInteger                         binding;
@property (nonatomic) NSString                           *name;

@end

@interface ShaderPassBindings : NSObject
@property (nonatomic) MTLPixelFormat                                format;
@property (nonatomic, readonly) NSArray<ShaderPassBufferBinding *>  *buffers;
@property (nonatomic, readonly) NSArray<ShaderPassTextureBinding *> *textures;

- (ShaderPassTextureBinding *)addTexture:(id<MTLTexture> __unsafe_unretained *)texture;

@end

@interface ShaderPassBufferSemantics : NSObject
@property (nonatomic) void *data;
@end

@interface ShaderPassTextureSemantics : NSObject
@property (nonatomic) id<MTLTexture> __unsafe_unretained *texture;
@property (nonatomic) size_t                             textureStride;
@property (nonatomic) void                               *textureSize;
@property (nonatomic) size_t                             sizeStride;
@end

@interface ShaderPassSemantics : NSObject

@property (nonatomic, readonly) NSDictionary<OEShaderTextureSemantic, ShaderPassTextureSemantics *> *textures;
@property (nonatomic, readonly) NSDictionary<OEShaderBufferSemantic, ShaderPassBufferSemantics *>   *uniforms;

- (void)addTexture:(id<MTLTexture> __unsafe_unretained *)texture
            stride:(size_t)ts
              size:(void *)size
            stride:(size_t)ss
          semantic:(OEShaderTextureSemantic)semantic;

- (void)addUniformData:(void *)data semantic:(OEShaderBufferSemantic)semantic;
@end
