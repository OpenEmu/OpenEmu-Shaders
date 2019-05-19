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

#import "ShaderReflection.h"
#import <OpenEmuShaders/OpenEmuShaders-Swift.h>

@implementation ShaderTextureSemanticMeta
@end

@implementation ShaderSemanticMeta
@end

@implementation ShaderTextureSemanticMap

+ (instancetype)mapWithSemantic:(OEShaderTextureSemantic)semantic index:(NSUInteger)index
{
    ShaderTextureSemanticMap *m = [self new];
    m.semantic = semantic;
    m.index    = index;
    return m;
}

@end

@implementation ShaderSemanticMap

+ (instancetype)mapWithSemantic:(OEShaderBufferSemantic)semantic index:(NSUInteger)index
{
    ShaderSemanticMap *m = [self new];
    m.semantic = semantic;
    m.index    = index;
    return m;
}

@end

@implementation ShaderReflection
{
    
    NSMutableDictionary<OEShaderTextureSemantic, NSMutableArray<ShaderTextureSemanticMeta *> *> *_textures;
    NSMutableDictionary<OEShaderBufferSemantic, ShaderSemanticMeta *>                           *_semantics;
    NSMutableArray<ShaderSemanticMeta *>                                                        *_floatParameters;
    
    NSMutableDictionary<NSString *, ShaderTextureSemanticMap *> *_textureSemanticMap;
    NSMutableDictionary<NSString *, ShaderTextureSemanticMap *> *_textureUniformSemanticMap;
    NSMutableDictionary<NSString *, ShaderSemanticMap *>        *_semanticMap;
}

static NSDictionary<OEShaderTextureSemantic, NSNumber *>    *textureSemanticArrays;
static NSDictionary<OEShaderTextureSemantic, NSString *>    *textureSemanticToName;
static NSDictionary<OEShaderTextureSemantic, NSString *>    *textureSemanticToUniformName;
static NSDictionary<NSString *, ShaderTextureSemanticMap *> *textureSemanticNames;
static NSDictionary<NSString *, ShaderTextureSemanticMap *> *textureSemanticUniformNames;
static NSDictionary<NSString *, ShaderSemanticMap *>        *semanticUniformNames;
static NSDictionary<OEShaderBufferSemantic, NSString *>     *semanticToUniformName;

+ (void)initialize
{
    dispatch_once_t once;
    dispatch_once(&once, ^{
        textureSemanticArrays = @{
                OEShaderTextureSemanticOriginal: @NO,
                OEShaderTextureSemanticSource: @NO,
                OEShaderTextureSemanticOriginalHistory: @YES,
                OEShaderTextureSemanticPassOutput: @YES,
                OEShaderTextureSemanticPassFeedback: @YES,
                OEShaderTextureSemanticUser: @YES,
        };
        textureSemanticNames  = @{
                @"Original": [ShaderTextureSemanticMap mapWithSemantic:OEShaderTextureSemanticOriginal index:0],
                @"Source": [ShaderTextureSemanticMap mapWithSemantic:OEShaderTextureSemanticSource index:1],
                @"OriginalHistory": [ShaderTextureSemanticMap mapWithSemantic:OEShaderTextureSemanticOriginalHistory index:2],
                @"PassOutput": [ShaderTextureSemanticMap mapWithSemantic:OEShaderTextureSemanticPassOutput index:3],
                @"PassFeedback": [ShaderTextureSemanticMap mapWithSemantic:OEShaderTextureSemanticPassFeedback index:4],
                @"User": [ShaderTextureSemanticMap mapWithSemantic:OEShaderTextureSemanticUser index:5],
        };
        textureSemanticToName = @{
                OEShaderTextureSemanticOriginal: @"Original",
                OEShaderTextureSemanticSource: @"Source",
                OEShaderTextureSemanticOriginalHistory: @"OriginalHistory",
                OEShaderTextureSemanticPassOutput: @"PassOutput",
                OEShaderTextureSemanticPassFeedback: @"PassFeedback",
                OEShaderTextureSemanticUser: @"User",
        };
        
        textureSemanticUniformNames  = @{
                @"OriginalSize": [ShaderTextureSemanticMap mapWithSemantic:OEShaderTextureSemanticOriginal index:0],
                @"SourceSize": [ShaderTextureSemanticMap mapWithSemantic:OEShaderTextureSemanticSource index:1],
                @"OriginalHistorySize": [ShaderTextureSemanticMap mapWithSemantic:OEShaderTextureSemanticOriginalHistory index:2],
                @"PassOutputSize": [ShaderTextureSemanticMap mapWithSemantic:OEShaderTextureSemanticPassOutput index:3],
                @"PassFeedbackSize": [ShaderTextureSemanticMap mapWithSemantic:OEShaderTextureSemanticPassFeedback index:4],
                @"UserSize": [ShaderTextureSemanticMap mapWithSemantic:OEShaderTextureSemanticUser index:5],
        };
        textureSemanticToUniformName = @{
                OEShaderTextureSemanticOriginal: @"OriginalSize",
                OEShaderTextureSemanticSource: @"SourceSize",
                OEShaderTextureSemanticOriginalHistory: @"OriginalHistorySize",
                OEShaderTextureSemanticPassOutput: @"PassOutputSize",
                OEShaderTextureSemanticPassFeedback: @"PassFeedbackSize",
                OEShaderTextureSemanticUser: @"UserSize",
        };
        
        semanticUniformNames  = @{
                @"MVP": [ShaderSemanticMap mapWithSemantic:OEShaderBufferSemanticMVP index:0],
                @"OutputSize": [ShaderSemanticMap mapWithSemantic:OEShaderBufferSemanticOutput index:1],
                @"FinalViewportSize": [ShaderSemanticMap mapWithSemantic:OEShaderBufferSemanticFinalViewportSize index:2],
                @"FrameCount": [ShaderSemanticMap mapWithSemantic:OEShaderBufferSemanticFrameCount index:3],
        };
        semanticToUniformName = @{
                OEShaderBufferSemanticMVP: @"MVP",
                OEShaderBufferSemanticOutput: @"OutputSize",
                OEShaderBufferSemanticFinalViewportSize: @"FinalViewportSize",
                OEShaderBufferSemanticFrameCount: @"FrameCount",
        };
    });
}

- (instancetype)init
{
    self = [super init];
    
    _textures = [NSMutableDictionary<OEShaderTextureSemantic, NSMutableArray<ShaderTextureSemanticMeta *> *> new];
    _textures[OEShaderTextureSemanticOriginal]        = [NSMutableArray<ShaderTextureSemanticMeta *> new];
    _textures[OEShaderTextureSemanticSource]          = [NSMutableArray<ShaderTextureSemanticMeta *> new];
    _textures[OEShaderTextureSemanticOriginalHistory] = [NSMutableArray<ShaderTextureSemanticMeta *> new];
    _textures[OEShaderTextureSemanticPassOutput]      = [NSMutableArray<ShaderTextureSemanticMeta *> new];
    _textures[OEShaderTextureSemanticPassFeedback]    = [NSMutableArray<ShaderTextureSemanticMeta *> new];
    _textures[OEShaderTextureSemanticUser]            = [NSMutableArray<ShaderTextureSemanticMeta *> new];
    
    _semantics = [NSMutableDictionary<OEShaderBufferSemantic, ShaderSemanticMeta *> new];
    _semantics[OEShaderBufferSemanticMVP]               = [ShaderSemanticMeta new];
    _semantics[OEShaderBufferSemanticOutput]            = [ShaderSemanticMeta new];
    _semantics[OEShaderBufferSemanticFinalViewportSize] = [ShaderSemanticMeta new];
    _semantics[OEShaderBufferSemanticFrameCount]        = [ShaderSemanticMeta new];
    
    _floatParameters           = [NSMutableArray<ShaderSemanticMeta *> new];
    _textureSemanticMap        = [NSMutableDictionary<NSString *, ShaderTextureSemanticMap *> new];
    _textureUniformSemanticMap = [NSMutableDictionary<NSString *, ShaderTextureSemanticMap *> new];
    _semanticMap               = [NSMutableDictionary<NSString *, ShaderSemanticMap *> new];
    
    return self;
}

- (BOOL)addTextureSemantic:(OEShaderTextureSemantic)semantic passIndex:(NSUInteger)i name:(NSString *)name
{
    ShaderTextureSemanticMap *e = _textureSemanticMap[name];
    if (e != nil) {
        NSLog(@"alias %@ already exists for texture semantic %@", name, semantic);
        return NO;
    }
    e = [ShaderTextureSemanticMap new];
    e.semantic = semantic;
    e.index    = i;
    _textureSemanticMap[name] = e;
    return YES;
}

- (BOOL)addTextureBufferSemantic:(OEShaderTextureSemantic)semantic passIndex:(NSUInteger)i name:(NSString *)name
{
    ShaderTextureSemanticMap *e = _textureUniformSemanticMap[name];
    if (e != nil) {
        NSLog(@"alias %@ already exists for texture semantic %@", name, semantic);
        return NO;
    }
    e = [ShaderTextureSemanticMap new];
    e.semantic = semantic;
    e.index    = i;
    _textureUniformSemanticMap[name] = e;
    return YES;
}

- (BOOL)addBufferSemantic:(OEShaderBufferSemantic)semantic passIndex:(NSUInteger)i name:(NSString *)name
{
    ShaderSemanticMap *e = _semanticMap[name];
    if (e != nil) {
        NSLog(@"alias %@ already exists for buffer semantic %@", name, semantic);
        return NO;
    }
    e = [ShaderSemanticMap new];
    e.semantic = semantic;
    e.index    = i;
    _semanticMap[name] = e;
    return YES;
}

- (NSString *)nameForBufferSemantic:(OEShaderBufferSemantic)semantic index:(NSUInteger)index
{
    NSString *name = semanticToUniformName[semantic];
    if (name != nil) {
        return name;
    }
    
    for (NSString *key in _semanticMap) {
        ShaderSemanticMap *map = _semanticMap[key];
        if (map.semantic == semantic && map.index == index) {
            return key;
        }
    }
    return nil;
}

- (NSString *)nameForTextureSemantic:(OEShaderTextureSemantic)semantic index:(NSUInteger)index
{
    NSString *name = textureSemanticToName[semantic];
    if (name != nil) {
        return name;
    }
    
    for (NSString *key in _textureSemanticMap) {
        ShaderSemanticMap *map = _semanticMap[key];
        if (map.semantic == semantic && map.index == index) {
            return key;
        }
    }
    return nil;
}

- (NSString *)sizeNameForTextureSemantic:(OEShaderTextureSemantic)semantic index:(NSUInteger)index
{
    NSString *name = textureSemanticToUniformName[semantic];
    if (name != nil) {
        return name;
    }
    
    for (NSString *key in _textureUniformSemanticMap) {
        ShaderSemanticMap *map = _semanticMap[key];
        if (map.semantic == semantic && map.index == index) {
            return key;
        }
    }
    return nil;
}

- (ShaderSemanticMap *)bufferSemanticForUniformName:(NSString *)name
{
    ShaderSemanticMap *res = _semanticMap[name];
    if (res) {
        return res;
    }
    
    return semanticUniformNames[name];
}

- (BOOL)textureSemanticIsArray:(OEShaderTextureSemantic)semantic
{
    return [textureSemanticArrays[semantic] boolValue];
}

- (ShaderTextureSemanticMap *)textureSemanticForUniformName:(NSString *)name names:(NSDictionary<NSString *, ShaderTextureSemanticMap *> *)names
{
    
    for (NSString *key in names) {
        ShaderTextureSemanticMap *sem = names[key];
        if ([self textureSemanticIsArray:sem.semantic]) {
            if ([name hasPrefix:key]) {
                NSUInteger index = (NSUInteger)[[name substringFromIndex:key.length] integerValue];
                return [ShaderTextureSemanticMap mapWithSemantic:sem.semantic index:index];
            }
        } else if ([name isEqualToString:key]) {
            return [ShaderTextureSemanticMap mapWithSemantic:sem.semantic index:0];
        }
    }
    return nil;
}

- (ShaderTextureSemanticMap *)textureSemanticForUniformName:(NSString *)name
{
    ShaderTextureSemanticMap *res = _textureUniformSemanticMap[name];
    if (res) {
        return res;
    }
    
    return [self textureSemanticForUniformName:name names:textureSemanticUniformNames];
}

- (ShaderTextureSemanticMap *)textureSemanticForName:(NSString *)name
{
    ShaderTextureSemanticMap *res = _textureSemanticMap[name];
    if (res) {
        return res;
    }
    
    return [self textureSemanticForUniformName:name names:textureSemanticNames];
}

- (void)resizeArray:(NSMutableArray *)array withCapacity:(NSUInteger)items class:(Class)class
{
    if (array.count > items) {
        return;
    }
    
    while (array.count <= items) {
        [array addObject:[class new]];
    }
}

- (BOOL)setOffset:(size_t)offset vecSize:(unsigned)vecSize forFloatParameterAtIndex:(NSUInteger)index ubo:(BOOL)ubo
{
    [self resizeArray:_floatParameters withCapacity:index class:ShaderSemanticMeta.class];
    
    ShaderSemanticMeta *sem = _floatParameters[index];
    if (sem == nil) {
        sem = [ShaderSemanticMeta new];
        _floatParameters[index] = sem;
    }
    
    if (sem.numberOfComponents != vecSize && (sem.uboActive || sem.pushActive)) {
        NSLog(@"vertex and fragment shaders have different data type sizes for same parameter #%lu (%lu / %lu)",
                index, sem.numberOfComponents, (size_t)vecSize);
        return NO;
    }
    
    if (ubo) {
        if (sem.uboActive && sem.uboOffset != offset) {
            NSLog(@"vertex and fragment shaders have different offsets for same parameter #%lu (%lu / %lu)",
                    index, sem.uboOffset, offset);
            return NO;
        }
        sem.uboActive = YES;
        sem.uboOffset = offset;
    } else {
        if (sem.pushActive && sem.pushOffset != offset) {
            NSLog(@"vertex and fragment shaders have different offsets for same parameter #%lu (%lu / %lu)",
                    index, sem.pushOffset, offset);
            return NO;
        }
        sem.pushActive = YES;
        sem.pushOffset = offset;
    }
    
    sem.numberOfComponents = vecSize;
    return YES;
}

- (BOOL)setOffset:(size_t)offset vecSize:(unsigned)vecSize forSemantic:(OEShaderBufferSemantic)semantic ubo:(BOOL)ubo
{
    ShaderSemanticMeta *sem = _semantics[semantic];
    
    if (sem.numberOfComponents != vecSize && (sem.uboActive || sem.pushActive)) {
        NSLog(@"vertex and fragment shaders have different data type sizes for same semantic %@ (%lu / %lu)",
                semantic, sem.numberOfComponents, (size_t)vecSize);
        return NO;
    }
    
    if (ubo) {
        if (sem.uboActive && sem.uboOffset != offset) {
            NSLog(@"vertex and fragment shaders have different offsets for same semantic %@ (%lu / %lu)",
                    semantic, sem.uboOffset, offset);
            return NO;
        }
        sem.uboActive = YES;
        sem.uboOffset = offset;
    } else {
        if (sem.pushActive && sem.pushOffset != offset) {
            NSLog(@"vertex and fragment shaders have different offsets for same semantic %@ (%lu / %lu)",
                    semantic, sem.pushOffset, offset);
            return NO;
        }
        sem.pushActive = YES;
        sem.pushOffset = offset;
    }
    sem.numberOfComponents  = vecSize;
    return YES;
}

- (BOOL)setOffset:(size_t)offset forTextureSemantic:(OEShaderTextureSemantic)semantic atIndex:(NSUInteger)index ubo:(BOOL)ubo
{
    NSMutableArray<ShaderTextureSemanticMeta *> *array = _textures[semantic];
    [self resizeArray:array withCapacity:index class:ShaderTextureSemanticMeta.class];
    
    ShaderTextureSemanticMeta *sem = array[index];
    if (sem == nil) {
        sem = [ShaderTextureSemanticMeta new];
        array[index] = sem;
    }
    
    if (ubo) {
        if (sem.uboActive && sem.uboOffset != offset) {
            NSLog(@"vertex and fragment shaders have different offsets for same semantic %@ #%lu (%lu / %lu)",
                    semantic, index, sem.uboOffset, offset);
            return NO;
        }
        sem.uboActive = YES;
        sem.uboOffset = offset;
    } else {
        if (sem.pushActive && sem.pushOffset != offset) {
            NSLog(@"vertex and fragment shaders have different offsets for same semantic %@ #%lu (%lu / %lu)",
                    semantic, index, sem.pushOffset, offset);
            return NO;
        }
        sem.pushActive = YES;
        sem.pushOffset = offset;
    }
    
    return YES;
}

- (BOOL)setBinding:(NSUInteger)binding forTextureSemantic:(OEShaderTextureSemantic)semantic atIndex:(NSUInteger)index
{
    NSMutableArray<ShaderTextureSemanticMeta *> *array = _textures[semantic];
    [self resizeArray:array withCapacity:index class:ShaderTextureSemanticMeta.class];
    
    ShaderTextureSemanticMeta *sem = array[index];
    if (sem == nil) {
        sem = [ShaderTextureSemanticMeta new];
        array[index] = sem;
    }
    
    sem.binding    = binding;
    sem.texture    = YES;
    sem.stageUsage = OEStageUsageFragment;
    
    return YES;
}

- (NSString *)debugDescription
{
    NSMutableString *desc = [NSMutableString string];
    [desc appendString:@"\n"];
    [desc appendString:@"  → textures:\n"];
    
    for (OEShaderTextureSemantic sem in OEShaderConstants.textureSemantics) {
        NSUInteger                     i = 0;
        for (ShaderTextureSemanticMeta *meta in _textures[sem]) {
            if (meta.texture) {
                [desc appendFormat:@"      %@ (#%lu)\n", sem, i];
            }
            i += 1;
        }
    }
    
    [desc appendString:@"\n"];
    [desc appendFormat:@"  → Uniforms (vertex: %s, fragment %s):\n",
                       _uboStageUsage & OEStageUsageVertex ? "YES" : "NO",
                       _uboStageUsage & OEStageUsageFragment ? "YES" : "NO"];
    for (OEShaderBufferSemantic  sem in OEShaderConstants.bufferSemantics) {
        ShaderSemanticMeta *meta = _semantics[sem];
        if (meta.uboActive) {
            [desc appendFormat:@"      UBO  %@ (offset: %lu)\n", sem, meta.uboOffset];
        }
    }
    for (OEShaderTextureSemantic sem in OEShaderConstants.textureSemantics) {
        NSUInteger                     i = 0;
        for (ShaderTextureSemanticMeta *meta in _textures[sem]) {
            if (meta.uboActive) {
                [desc appendFormat:@"      UBO  %@ (#%lu) (offset: %lu)\n", textureSemanticToUniformName[sem], i, meta.uboOffset];
            }
            i += 1;
        }
    }
    
    [desc appendString:@"\n"];
    [desc appendFormat:@"  → Push (vertex: %s, fragment %s):\n",
                       _pushStageUsage & OEStageUsageVertex ? "YES" : "NO",
                       _pushStageUsage & OEStageUsageFragment ? "YES" : "NO"];
    
    for (OEShaderBufferSemantic sem in OEShaderConstants.bufferSemantics) {
        ShaderSemanticMeta *meta = _semantics[sem];
        if (meta.pushActive) {
            [desc appendFormat:@"      PUSH %@ (offset: %lu)\n", sem, meta.pushOffset];
        }
    }
    
    for (OEShaderTextureSemantic sem in OEShaderConstants.textureSemantics) {
        NSUInteger                     i = 0;
        for (ShaderTextureSemanticMeta *meta in _textures[sem]) {
            if (meta.pushActive) {
                [desc appendFormat:@"      PUSH %@ (#%lu) (offset: %lu)\n", textureSemanticToUniformName[sem], i, meta.pushOffset];
            }
            i += 1;
        }
    }
    
    [desc appendString:@"\n"];
    [desc appendString:@"  → Parameters:\n"];
    
    NSUInteger              i = 0;
    for (ShaderSemanticMeta *meta in _floatParameters) {
        if (meta.uboActive) {
            [desc appendFormat:@"      UBO  #%lu (offset: %lu)\n", i, meta.uboOffset];
        }
        if (meta.pushActive) {
            [desc appendFormat:@"      PUSH #%lu (offset: %lu)\n", i, meta.pushOffset];
        }
        i += 1;
    }
    
    [desc appendString:@"\n"];
    
    return desc;
}

@end
