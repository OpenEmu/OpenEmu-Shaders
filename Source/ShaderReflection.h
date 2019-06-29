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

@import Foundation;
#import "SlangShader.h"
#import "ShaderPassSemantics.h"

@interface ShaderTextureSemanticMeta : NSObject
@property (nonatomic) NSUInteger   binding;
@property (nonatomic) NSUInteger   uboOffset;
@property (nonatomic) NSUInteger   pushOffset;
@property (nonatomic) OEStageUsage stageUsage;
@property (nonatomic) BOOL         texture;
@property (nonatomic) BOOL         uboActive;
@property (nonatomic) BOOL         pushActive;
@end

@interface ShaderSemanticMeta : NSObject
@property (nonatomic) NSUInteger uboOffset;
@property (nonatomic) NSUInteger pushOffset;
@property (nonatomic) NSUInteger numberOfComponents;
@property (nonatomic) BOOL       uboActive;
@property (nonatomic) BOOL       pushActive;
@end

@interface ShaderTextureSemanticMap : NSObject
@property (nonatomic) OEShaderTextureSemantic semantic;
@property (nonatomic) NSUInteger              index;
@end

@interface ShaderSemanticMap : NSObject
@property (nonatomic) OEShaderBufferSemantic semantic;
@property (nonatomic) NSUInteger             index;
@end

@interface ShaderReflection : NSObject

@property (nonatomic) NSUInteger                                                                                     passNumber;
@property (nonatomic) size_t                                                                                         uboSize;
@property (nonatomic) size_t                                                                                         pushSize;
@property (nonatomic) NSUInteger                                                                                     uboBindingVert;
@property (nonatomic) NSUInteger                                                                                     uboBindingFrag;
@property (nonatomic) NSUInteger                                                                                     pushBindingVert;
@property (nonatomic) NSUInteger                                                                                     pushBindingFrag;
@property (nonatomic) OEStageUsage                                                                                   uboStageUsage;
@property (nonatomic) OEStageUsage                                                                                   pushStageUsage;
@property (nonatomic, readonly) NSDictionary<OEShaderTextureSemantic, NSMutableArray<ShaderTextureSemanticMeta *> *> *textures;
@property (nonatomic, readonly) NSDictionary<OEShaderBufferSemantic, ShaderSemanticMeta *>                           *semantics;
@property (nonatomic, readonly) NSArray<ShaderSemanticMeta *>                                                        *floatParameters;

// aliases
@property (nonatomic, readonly) NSDictionary<NSString *, ShaderTextureSemanticMap *> *textureSemanticMap;
@property (nonatomic, readonly) NSDictionary<NSString *, ShaderTextureSemanticMap *> *textureUniformSemanticMap;
@property (nonatomic, readonly) NSDictionary<NSString *, ShaderSemanticMap *>        *semanticMap;

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
