/**
 * Copyright (c) 2019 Stuart Carnie
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

#import <Foundation/Foundation.h>
#import "SlangShader.h"
#import "spirv.h"
#import "spirv_cross_c.h"
#import "SlangCompiler.h"
#import "ShaderReflection.h"
#import "ShaderPassSemantics.h"
#import "NSScanner+Extensions.h"

/*!
 * SlangSource is responsible for parsing the .slang source file from the provided url.
 *
 * @details
 * Valid @c #pragma directives include @c name, @c format and @c parameter.
 */
@interface SlangSource : NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) SlangFormat format;
@property (nonatomic, readonly) NSDictionary<NSString *, ShaderParameter *> *parameters;

@property (nonatomic, readonly) NSString *vertexSource;
@property (nonatomic, readonly) NSString *fragmentSource;

- (instancetype)initFromURL:(NSURL *)url error:(NSError **)error;

@end

@implementation SlangSource {
    NSMutableArray<NSString *> *_buffer;
    NSMutableDictionary<NSString *, ShaderParameter *> *_parameters;
    NSString *_vertexSource;
    NSString *_fragmentSource;
}

+ (NSCharacterSet *)identifierChars {
    static dispatch_once_t once;
    static NSMutableCharacterSet *set;
    dispatch_once(&once, ^{
        set = [NSMutableCharacterSet characterSetWithBitmapRepresentation:NSCharacterSet.alphanumericCharacterSet.bitmapRepresentation];
        [set formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"_"]];
    });
    return set;
}

- (instancetype)initFromURL:(NSURL *)url error:(NSError **)error {
    self = [super init];

    _buffer = [NSMutableArray<NSString *> new];
    _parameters = [NSMutableDictionary<NSString *, ShaderParameter *> new];
    _format = SlangFormatUnknown;

    @autoreleasepool {
        NSError *err = nil;
        [self load:url isRoot:YES error:&err];

        if (err != nil) {
            if (error != nil) {
                *error = err;
            }
            return nil;
        }
    }

    return self;
}

- (void)load:(NSURL *)url isRoot:(BOOL)root error:(NSError **)error {
    NSString *f = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:error];
    if (*error != nil) {
        return;
    }

    NSArray<NSString *> *lines = [f componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
    NSString *filename = url.lastPathComponent;

    NSUInteger lno = 1;

    NSEnumerator<NSString *> *oe = lines.objectEnumerator;
    if (root) {
        NSString *line = oe.nextObject;

        if (![line hasPrefix:@"#version "]) {
            *error = [NSError errorWithDomain:OEShaderErrorDomain
                                         code:OEShaderMissingVersion
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: NSLocalizedString(@"Root slang shader missing #version", @"The slang file is missing the required #version directive")
                                     }];
            return;
        }
        [_buffer addObject:line];
        [_buffer addObject:@"#extension GL_GOOGLE_cpp_style_line_directive : require"];
        lno++;
    }

    [_buffer addObject:[NSString stringWithFormat:@"#line %lu \"%@\"", lno, filename]];

    for (NSString *line in oe) {
        if ([line hasPrefix:@"#include "]) {
            NSScanner *s = [NSScanner scannerWithString:line];
            [s scanString:@"#include " intoString:nil];
            NSString *filepath = nil;
            if (![s scanQuotedString:&filepath] || filepath.length == 0) {
                NSLog(@"missing file");
                // TODO(sgc): fix this
            }
            NSURL *file = [NSURL fileURLWithPath:filepath relativeToURL:url.URLByDeletingLastPathComponent];
            [self load:file isRoot:NO error:error];
            if (*error != nil) {
                return;
            }

            // add line directive to reset to this file after include
            [_buffer addObject:[NSString stringWithFormat:@"#line %lu \"%@\"", lno, filename]];
        } else {
            [_buffer addObject:line];

            BOOL hasPreprocessor = NO;
            if ([line hasPrefix:@"#pragma"]) {
                hasPreprocessor = YES;
                [self processPragma:line error:error];
            } else if ([line hasPrefix:@"#endif"]) {
                hasPreprocessor = YES;
            }

            if (hasPreprocessor) {
                [_buffer addObject:[NSString stringWithFormat:@"#line %lu \"%@\"", lno + 1, filename]];
            }
        }
        lno += 1;
    }
}

- (void)processPragma:(NSString *)pragma error:(NSError **)error {
    if ([pragma hasPrefix:@"#pragma name "]) {
        if (_name != nil) {
            *error = [NSError errorWithDomain:OEShaderErrorDomain
                                         code:OEShaderMultipleNamePragma
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: NSLocalizedString(@"#pragma name declared multiple times", @"The slang file contains multiple declarations of the #pragma name directive")
                                     }];
            return;

        }
    } else if ([pragma hasPrefix:@"#pragma parameter "]) {
        NSScanner *scan = [NSScanner scannerWithString:pragma];
        [scan scanString:@"#pragma parameter " intoString:nil];

        int count = 0;
        NSString *name;
        count += [scan scanCharactersFromSet:self.class.identifierChars intoString:&name] ? 1 : 0;

        NSString *desc;
        count += [scan scanQuotedString:&desc] ? 1 : 0;

        float initial, minimum, maximum, step;
        count += [scan scanFloat:&initial] ? 1 : 0;
        count += [scan scanFloat:&minimum] ? 1 : 0;
        count += [scan scanFloat:&maximum] ? 1 : 0;
        count += [scan scanFloat:&step] ? 1 : 0;
        if (count == 5) {
            step = 0.1f * (maximum - minimum);
            count += 1;
        }

        if (count == 6) {
            // valid parameter
            ShaderParameter *param = [ShaderParameter new];
            param.name = name;
            param.desc = desc;
            param.initial = initial;
            param.value = initial;
            param.minimum = minimum;
            param.maximum = maximum;
            param.step = step;

            ShaderParameter *existing = _parameters[name];
            if (existing != nil && ![param isEqual:existing]) {
                *error = [NSError errorWithDomain:OEShaderErrorDomain
                                             code:OEShaderDuplicateParameterPragma
                                         userInfo:@{
                                             NSLocalizedDescriptionKey: NSLocalizedString(@"duplicate #pragma parameter", @"The slang file contains duplicate #pragma parameter directives")
                                         }];
                return;
            }
            _parameters[name] = param;
        } else {
            *error = [NSError errorWithDomain:OEShaderErrorDomain
                                         code:OEShaderMultipleFormatPragma
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: NSLocalizedString(@"#pragma parameter format invalid", @"The slang file contains an invalid #pragma parameter directive")
                                     }];
            return;
        }
    } else if ([pragma hasPrefix:@"#pragma format "]) {
        if (_format != SlangFormatUnknown) {
            *error = [NSError errorWithDomain:OEShaderErrorDomain
                                         code:OEShaderMultipleFormatPragma
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: NSLocalizedString(@"#pragma format declared multiple times", @"The slang file contains multiple declarations of the #pragma format directive")
                                     }];
            return;
        }

        NSScanner *scan = [NSScanner scannerWithString:pragma];
        [scan scanString:@"#pragma format " intoString:nil];
        int count = 0;
        NSString *fmt;
        [scan scanCharactersFromSet:self.class.identifierChars intoString:&fmt];
        _format = SlangFormatFromGLSlangNSString(fmt);
        if (_format == SlangFormatUnknown) {
            *error = [NSError errorWithDomain:OEShaderErrorDomain
                                         code:OEShaderMultipleFormatPragma
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: NSLocalizedString(@"#pragma format is invalid", @"The slang file contains an invalid format directive")
                                     }];
            return;
        }
    }
}

- (NSString *)findSourceForStage:(NSString *)stage {
    NSMutableArray<NSString *> *src = [NSMutableArray new];

    NSEnumerator<NSString *> *lines = _buffer.objectEnumerator;
    [src addObject:lines.nextObject];

    BOOL store = YES;

    for (NSString *line in lines) {
        if ([line hasPrefix:@"#pragma stage "]) {
            NSScanner *scan = [NSScanner scannerWithString:line];
            [scan scanString:@"#pragma stage " intoString:nil];
            NSString *v;
            [scan scanCharactersFromSet:NSCharacterSet.alphanumericCharacterSet intoString:&v];
            store = [v isEqualToString:stage];
        } else if ([line hasPrefix:@"#pragma name "] || [line hasPrefix:@"#pragma format "]) {
            // skip
        } else if (store) {
            [src addObject:line];
        }
    }

    return [src componentsJoinedByString:@"\n"];
}

- (NSString *)vertexSource {
    if (_vertexSource == nil) {
        _vertexSource = [self findSourceForStage:@"vertex"];
    }
    return _vertexSource;
}

- (NSString *)fragmentSource {
    if (_fragmentSource == nil) {
        _fragmentSource = [self findSourceForStage:@"fragment"];
    }
    return _fragmentSource;
}

@end


static NSString *IDToNSString(id obj) {
    if ([obj isKindOfClass:NSString.class])
        return (NSString *) obj;
    return nil;
}

static ShaderPassWrap ShaderPassWrapFromNSString(NSString *wrapMode) {
    if (wrapMode == nil)
        return ShaderPassWrapDefault;

    if ([wrapMode isEqualToString:@"clamp_to_border"])
        return ShaderPassWrapBorder;
    else if ([wrapMode isEqualToString:@"clamp_to_edge"])
        return ShaderPassWrapEdge;
    else if ([wrapMode isEqualToString:@"repeat"])
        return ShaderPassWrapRepeat;
    else if ([wrapMode isEqualToString:@"mirrored_repeat"])
        return ShaderPassWrapMirroredRepeat;

    NSLog(@"invalid wrap mode %@. Choose from clamp_to_border, clamp_to_edge, repeat or mirrored_repeat", wrapMode);

    return ShaderPassWrapDefault;
}

static ShaderPassScale ShaderPassScaleFromNSString(NSString *scale) {
    if ([scale isEqualToString:@"source"])
        return ShaderPassScaleInput;
    if ([scale isEqualToString:@"viewport"])
        return ShaderPassScaleViewport;
    if ([scale isEqualToString:@"absolute"])
        return ShaderPassScaleAbsolute;
    return ShaderPassScaleInvalid;
}

static ShaderPassFilter ShaderPassFilterFromObject(id obj) {
    if (obj == nil) {
        return ShaderPassFilterUnspecified;
    }

    if ([obj boolValue]) {
        return ShaderPassFilterLinear;
    }
    return ShaderPassFilterNearest;
}

@interface ShaderPass ()
@property (nonatomic, readonly) SlangSource *source;
@end

@implementation ShaderPass {
    NSURL *_url;
    NSUInteger _index;
    SlangSource *_source;
}

- (instancetype)initWithURL:(NSURL *)url
                      index:(NSUInteger)index
                 dictionary:(NSDictionary *)d {
    if (self = [super init]) {
        _url = url;
        _index = index;
        _source = [[SlangSource alloc] initFromURL:url error:nil];
        
        self.filter = ShaderPassFilterFromObject(d[@"filterLinear"]);
        self.wrapMode = ShaderPassWrapFromNSString(IDToNSString(d[@"wrapMode"]));

        id obj = nil;

        if ((obj = d[@"frameCountMod"]) != nil) {
            self.frameCountMod = [obj unsignedIntegerValue];
        }

        if ((obj = d[@"srgbFramebuffer"]) != nil) {
            self.issRGB = [obj boolValue];
        }

        if ((obj = d[@"floatFramebuffer"]) != nil) {
            self.isFloat = [obj boolValue];
        }

        if ((obj = d[@"mipmapInput"]) != nil) {
            self.isMipmap = [obj boolValue];
        }

        self.alias = IDToNSString(d[@"alias"]);
        if (self.alias == nil || self.alias.length == 0) {
            self.alias = self.source.name;
        }
        
        if (d[@"scaleType"] != nil || d[@"scaleTypeX"] != nil || d[@"scaleTypeY"] != nil) {
            // scale
            self.valid = YES;
            self.scaleX = ShaderPassScaleInput;
            self.scaleY = ShaderPassScaleInput;
            CGSize size = {0};
            CGSize scale = CGSizeMake(1.0, 1.0);
            
            NSString *str = nil;
            if ((str = IDToNSString(d[@"scaleType"])) != nil) {
                self.scaleX = ShaderPassScaleFromNSString(str);
                self.scaleY = self.scaleX;
            } else {
                if ((str = IDToNSString(d[@"scaleTypeX"])) != nil) {
                    self.scaleX = ShaderPassScaleFromNSString(str);
                }
                if ((str = IDToNSString(d[@"scaleTypeY"])) != nil) {
                    self.scaleX = ShaderPassScaleFromNSString(str);
                }
            }
            
            // scale-x
            if ((obj = d[@"scale"] ?: d[@"scaleX"]) != nil) {
                if (self.scaleX == ShaderPassScaleAbsolute) {
                    size.width = [obj unsignedIntegerValue];
                } else {
                    scale.width = [obj doubleValue];
                }
            }
            
            // scale-y
            if ((obj = d[@"scale"] ?: d[@"scaleY"]) != nil) {
                if (self.scaleY == ShaderPassScaleAbsolute) {
                    size.height = [obj unsignedIntegerValue];
                } else {
                    scale.height = [obj doubleValue];
                }
            }
            
            self.size = size;
            self.scale = scale;
        }
    }
    return self;
}

- (SlangFormat)format {
    SlangFormat format = _source.format;
    if (format == SlangFormatUnknown) {
        if (_issRGB) {
            format = SlangFormatR8G8B8A8Srgb;
        } else if (_isFloat) {
            format = SlangFormatR16G16B16A16Sfloat;
        } else {
            format = SlangFormatR8G8B8A8Unorm;
        }
    }
    return format;
}

@end

@implementation ShaderLUT {
}

- (instancetype)initWithURL:(NSURL *)url
                       name:(NSString *)name
                 dictionary:(NSDictionary *)d {
    if (self = [super init]) {
        _url = url;
        _name = name;

        self.filter = ShaderPassFilterFromObject(d[@"linear"]);
        self.wrapMode = ShaderPassWrapFromNSString(IDToNSString(d[@"wrapMode"]));

        id obj = nil;
        if ((obj = d[@"mipmapInput"]) != nil) {
            self.isMipmap = [obj boolValue];
        }
    }
    return self;
}


@end

@implementation SlangShader {
    ShaderType _type;
    NSURL *_url;
    NSMutableArray<ShaderPass *> *_passes;
    NSMutableArray<ShaderLUT *> *_luts;
    NSMutableArray<ShaderParameter *> *_parameters;
    NSMutableDictionary<NSString *, ShaderParameter *> *_parametersMap;
}

- (instancetype)initFromURL:(NSURL *)url {
    if (self = [super init]) {
        _url = url;
        _parameters = [NSMutableArray new];
        _parametersMap = [NSMutableDictionary new];

        NSURL *base = [url URLByDeletingLastPathComponent];

        NSDictionary *d = [NSDictionary dictionaryWithContentsOfURL:url];

        NSArray *passes = d[@"passes"];
        _passes = [NSMutableArray arrayWithCapacity:passes.count];

        NSUInteger i = 0;
        for (NSDictionary *spec in passes) {
            NSString *path = spec[@"shader"];
            _passes[i] = [[ShaderPass alloc] initWithURL:[NSURL fileURLWithPath:path
                                                                  relativeToURL:base]
                                                   index:i
                                              dictionary:spec];
            i++;
        }

        // parse look-up textures
        NSDictionary < NSString *, NSDictionary * > *textures = d[@"textures"];
        if (textures != nil) {
            _luts = [NSMutableArray arrayWithCapacity:textures.count];
            i = 0;
            for (NSString *key in textures.keyEnumerator) {
                NSDictionary *spec = textures[key];
                NSString *path = spec[@"path"];
                _luts[i] = [[ShaderLUT alloc] initWithURL:[NSURL fileURLWithPath:path
                                                                   relativeToURL:base]
                                                     name:key
                                               dictionary:spec];
                i++;
            }
        }

        // collect parameters
        i = 0;
        for (ShaderPass *pass in _passes) {
            NSDictionary < NSString *, ShaderParameter * > *params = pass.source.parameters;
            for (ShaderParameter *param in params.objectEnumerator) {
                ShaderParameter *existing = _parametersMap[param.name];
                if (existing != nil && ![param isEqual:existing]) {
                    // TODO(SGC) conflicting parameters
                    assert("conflicting parameters");
                }
                [_parameters addObject:param];
                _parametersMap[param.name] = param;
            }
            i++;
        }

        // resolve overrides from .plist
        NSDictionary < NSString *, NSNumber * > *params = d[@"parameters"];
        if (params != nil) {
            for (NSString *name in params) {
                ShaderParameter *existing = _parametersMap[name];
                if (existing) {
                    existing.initial = [params[name] floatValue];
                    existing.value = [params[name] floatValue];
                }
            }
        }
    }
    return self;
}

// typedef void (*spvc_error_callback)(void *userdata, const char *error);

void error_callback(void *userdata, const char *error) {
    SlangShader *pass = (__bridge SlangShader *) userdata;
    [pass compileError:error];
}

- (void)compileError:(char const *)error {

}

- (BOOL)buildPass:(NSUInteger)passNumber
     metalVersion:(NSUInteger)version
    passSemantics:(ShaderPassSemantics *)passSemantics
     passBindings:(ShaderPassBindings *)passBindings
           vertex:(NSString **)vsrc
         fragment:(NSString **)fsrc {

    ShaderPass *pass = _passes[passNumber];
    passBindings.format = pass.format;


    spvc_context ctx;
    spvc_context_create(&ctx);

    spvc_context_set_error_callback(ctx, error_callback, (__bridge void *) self);

    // vertex shader
    SlangCompiler *c = [SlangCompiler new];
    ShaderProgram *vs = [c compileVertex:pass.source.vertexSource error:nil];

    spvc_parsed_ir vs_ir = nil;
    spvc_context_parse_spirv(ctx, vs.spirv, vs.spirvLength, &vs_ir);

    spvc_compiler vs_compiler;
    spvc_context_create_compiler(ctx, SPVC_BACKEND_MSL, vs_ir, SPVC_CAPTURE_MODE_TAKE_OWNERSHIP, &vs_compiler);

    spvc_resources vs_resources = nil;
    spvc_compiler_create_shader_resources(vs_compiler, &vs_resources);

    spvc_reflected_resource const *resource = nil;
    size_t resource_size;

    spvc_resources_get_resource_list_for_type(vs_resources, SPVC_RESOURCE_TYPE_UNIFORM_BUFFER, &resource, &resource_size);
    if (resource_size > 0) {
        spvc_compiler_set_decoration(vs_compiler, resource[0].id, SpvDecorationBinding, 0);
    }
    spvc_resources_get_resource_list_for_type(vs_resources, SPVC_RESOURCE_TYPE_PUSH_CONSTANT, &resource, &resource_size);
    if (resource_size > 0) {
        spvc_compiler_set_decoration(vs_compiler, resource[0].id, SpvDecorationBinding, 1);
    }

    // vertex compile
    spvc_compiler_options vs_options;
    spvc_compiler_create_compiler_options(vs_compiler, &vs_options);
    spvc_compiler_options_set_uint(vs_options, SPVC_COMPILER_OPTION_MSL_VERSION, (unsigned int)version);
    spvc_compiler_install_compiler_options(vs_compiler, vs_options);
    char const *vs_code;
    spvc_compiler_compile(vs_compiler, &vs_code);
    *vsrc = [NSString stringWithUTF8String:vs_code];

    // fragment shader
    c = [SlangCompiler new];
    ShaderProgram *fs = [c compileFragment:pass.source.fragmentSource error:nil];

    spvc_parsed_ir fs_ir = nil;
    spvc_context_parse_spirv(ctx, fs.spirv, fs.spirvLength, &fs_ir);

    spvc_compiler fs_compiler;
    spvc_context_create_compiler(ctx, SPVC_BACKEND_MSL, fs_ir, SPVC_CAPTURE_MODE_TAKE_OWNERSHIP, &fs_compiler);

    spvc_resources fs_resources = nil;
    spvc_compiler_create_shader_resources(fs_compiler, &fs_resources);

    spvc_resources_get_resource_list_for_type(fs_resources, SPVC_RESOURCE_TYPE_UNIFORM_BUFFER, &resource, &resource_size);
    if (resource_size > 0) {
        spvc_compiler_set_decoration(fs_compiler, resource[0].id, SpvDecorationBinding, 0);
    }
    spvc_resources_get_resource_list_for_type(fs_resources, SPVC_RESOURCE_TYPE_PUSH_CONSTANT, &resource, &resource_size);
    if (resource_size > 0) {
        spvc_compiler_set_decoration(fs_compiler, resource[0].id, SpvDecorationBinding, 1);
    }

    // fragment compile
    spvc_compiler_options fs_options;
    spvc_compiler_create_compiler_options(fs_compiler, &fs_options);
    spvc_compiler_options_set_uint(fs_options, SPVC_COMPILER_OPTION_MSL_VERSION, 20000);
    spvc_compiler_install_compiler_options(fs_compiler, fs_options);
    char const *fs_code;
    spvc_compiler_compile(fs_compiler, &fs_code);
    *fsrc = [NSString stringWithUTF8String:fs_code];

    BOOL res = [self processPass:passNumber
              withVertexCompiler:vs_compiler
                fragmentCompiler:fs_compiler
                 vertexResources:vs_resources
               fragmentResources:fs_resources
                   passSemantics:passSemantics
                    passBindings:passBindings];

    spvc_context_destroy(ctx);

    return res;
}

- (BOOL)processPass:(NSUInteger)passNumber
 withVertexCompiler:(spvc_compiler)vsCompiler
   fragmentCompiler:(spvc_compiler)fsCompiler
    vertexResources:(spvc_resources)vsResources
  fragmentResources:(spvc_resources)fsResources
      passSemantics:(ShaderPassSemantics *)passSemantics
       passBindings:(ShaderPassBindings *)passBindings {

    ShaderReflection *ref = [ShaderReflection new];
    ref.passNumber = passNumber;

    // add aliases
    for (NSUInteger i = 0; i <= passNumber; i++) {
        ShaderPass *pass = _passes[i];
        if (pass.alias.length == 0) {
            continue;
        }

        NSString *name = pass.alias;

        if (![ref addTextureSemantic:OEShaderTextureSemanticPassOutput passIndex:i name:name]) {
            return NO;
        }
        if (![ref addTextureBufferSemantic:OEShaderTextureSemanticPassOutput passIndex:i name:[name stringByAppendingString:@"Size"]]) {
            return NO;
        }
        if (![ref addTextureSemantic:OEShaderTextureSemanticPassFeedback passIndex:i name:[name stringByAppendingString:@"Feedback"]]) {
            return NO;
        }
        if (![ref addTextureBufferSemantic:OEShaderTextureSemanticPassFeedback passIndex:i name:[name stringByAppendingString:@"FeedbackSize"]]) {
            return NO;
        }
    }

    for (NSUInteger i = 0; i < _luts.count; i++) {
        ShaderLUT *lut = _luts[i];
        if (![ref addTextureSemantic:OEShaderTextureSemanticUser passIndex:i name:lut.name]) {
            return NO;
        }
        if (![ref addTextureBufferSemantic:OEShaderTextureSemanticUser passIndex:i name:[lut.name stringByAppendingString:@"Size"]]) {
            return NO;
        }
    }

    for (NSUInteger i = 0; i < _parameters.count; i++) {
        ShaderParameter *param = _parameters[i];
        if (![ref addBufferSemantic:OEShaderBufferSemanticFloatParameter passIndex:i name:param.name]) {
            return NO;
        }
    }

    if (![self reflectWith:ref withVertexCompiler:vsCompiler fragmentCompiler:fsCompiler vertexResources:vsResources fragmentResources:fsResources]) {
        // TODO(sgc): unable to reflect SPIR-V program data
        NSLog(@"reflect failed");
        return NO;
    }

    // UBO
    ShaderPassBufferBinding *uboB = passBindings.buffers[0];
    uboB.stageUsage = ref.uboStageUsage;
    uboB.binding = ref.uboBinding;
    uboB.size = (ref.uboSize + 0xf) & ~0xf; // round up to nearest 16 bytes

    // push constants
    ShaderPassBufferBinding *pshB = passBindings.buffers[1];
    pshB.stageUsage = ref.pushStageUsage;
    pshB.binding = ref.uboBinding ? 0 : 1; // if there is a UBO, this should be binding 0
    pshB.size = (ref.pushSize + 0xf) & ~0xf; // round up to nearest 16 bytes

    for (OEShaderBufferSemantic sem in ref.semantics) {
        ShaderSemanticMeta *meta = ref.semantics[sem];
        NSString *name = [ref nameForBufferSemantic:sem index:0];
        if (meta.uboActive) {
            [uboB addUniformData:passSemantics.uniforms[sem].data
                            size:meta.numberOfComponents * sizeof(float)
                          offset:meta.uboOffset
                            name:name];
        } else if (meta.pushActive) {
            [pshB addUniformData:passSemantics.uniforms[sem].data
                            size:meta.numberOfComponents * sizeof(float)
                          offset:meta.pushOffset
                            name:name];
        }
    }

    NSUInteger i = 0;
    for (ShaderSemanticMeta *meta in ref.floatParameters) {
        NSString *name = [ref nameForBufferSemantic:OEShaderBufferSemanticFloatParameter index:i];
        ShaderParameter *param = _parameters[i];
        if (meta.uboActive) {
            [uboB addUniformData:param.valuePtr
                            size:meta.numberOfComponents * sizeof(float)
                          offset:meta.uboOffset
                            name:name];
        } else if (meta.pushActive) {
            [pshB addUniformData:param.valuePtr
                            size:meta.numberOfComponents * sizeof(float)
                          offset:meta.pushOffset
                            name:name];
        }
        i++;
    }

    for (OEShaderTextureSemantic sem in ref.textures) {
        NSArray<ShaderTextureSemanticMeta *> *a = ref.textures[sem];
        ShaderPassTextureSemantics *tex = passSemantics.textures[sem];

        NSUInteger index = 0;
        for (ShaderTextureSemanticMeta *meta in a) {
            if (meta.stageUsage != StageUsageNone) {
                ShaderPassTextureBinding *bind = [passBindings addTexture:(id<MTLTexture> __unsafe_unretained *)(void *)((uintptr_t)(void *)tex.texture + index * tex.textureStride)];

                if (sem == OEShaderTextureSemanticUser) {
                    bind.wrap = _luts[index].wrapMode;
                    bind.filter = _luts[index].filter;
                } else {
                    bind.wrap = _passes[passNumber].wrapMode;
                    bind.filter = _passes[passNumber].filter;
                }

                bind.stageUsage = meta.stageUsage;
                bind.binding = meta.binding;
                bind.name = [ref nameForTextureSemantic:sem index:index];

                if (sem == OEShaderTextureSemanticPassFeedback) {
                    _passes[index].isFeedback = YES;
                } else if (sem == OEShaderTextureSemanticOriginalHistory && _historySize < index) {
                    _historySize = index;
                }
            }

            NSString *name = [ref sizeNameForTextureSemantic:sem index:0];
            if (meta.uboActive) {
                [uboB addUniformData:(void *)((uintptr_t)tex.textureSize + index * tex.sizeStride)
                                size:4 * sizeof(float)
                              offset:meta.uboOffset
                                name:name];
            } else if (meta.pushActive) {
                [pshB addUniformData:(void *)((uintptr_t)tex.textureSize + index * tex.sizeStride)
                                size:4 * sizeof(float)
                              offset:meta.pushOffset
                                name:name];
            }
            index++;
        }
    }

    // prepare map
    return YES;
}

- (BOOL)reflectWith:(ShaderReflection *)ref withVertexCompiler:(spvc_compiler)vsCompiler fragmentCompiler:(spvc_compiler)fsCompiler
    vertexResources:(spvc_resources)vsResources fragmentResources:(spvc_resources)fsResources {

    spvc_reflected_resource const *list;
    size_t list_size;
#define CHECK_EMPTY(RES, TYPE) list_size = 0; \
    spvc_resources_get_resource_list_for_type(RES, TYPE, &list, &list_size); \
    if (list_size > 0) { \
        NSLog(@"unexpected resource type in shader %@", @#TYPE); \
        return NO; \
    }
    CHECK_EMPTY(vsResources, SPVC_RESOURCE_TYPE_SAMPLED_IMAGE);
    CHECK_EMPTY(vsResources, SPVC_RESOURCE_TYPE_STORAGE_BUFFER);
    CHECK_EMPTY(vsResources, SPVC_RESOURCE_TYPE_SUBPASS_INPUT);
    CHECK_EMPTY(vsResources, SPVC_RESOURCE_TYPE_STORAGE_IMAGE);
    CHECK_EMPTY(vsResources, SPVC_RESOURCE_TYPE_ATOMIC_COUNTER);
    CHECK_EMPTY(fsResources, SPVC_RESOURCE_TYPE_STORAGE_BUFFER);
    CHECK_EMPTY(fsResources, SPVC_RESOURCE_TYPE_SUBPASS_INPUT);
    CHECK_EMPTY(fsResources, SPVC_RESOURCE_TYPE_STORAGE_IMAGE);
    CHECK_EMPTY(fsResources, SPVC_RESOURCE_TYPE_ATOMIC_COUNTER);
#undef CHECK_EMPTY

    // validate input to vertex shader
    list_size = 0;
    spvc_resources_get_resource_list_for_type(vsResources, SPVC_RESOURCE_TYPE_STAGE_INPUT, &list, &list_size);
    if (list_size != 2) {
        NSLog(@"vertex shader input must have two attributes");
        return NO;
    }

    NSUInteger mask = 0;
    mask |= 1 << spvc_compiler_get_decoration(vsCompiler, list[0].id, SpvDecorationLocation);
    mask |= 1 << spvc_compiler_get_decoration(vsCompiler, list[1].id, SpvDecorationLocation);
    if (mask != 0x03) {
        NSLog(@"vertex shader input attributes must use (location = 0) and (location = 1)");
        return NO;
    }

    // validate number of render targets for fragment shader
    list_size = 0;
    spvc_resources_get_resource_list_for_type(fsResources, SPVC_RESOURCE_TYPE_STAGE_OUTPUT, &list, &list_size);
    if (list_size != 1) {
        NSLog(@"fragment shader must have a single output");
        return NO;
    }

    if (spvc_compiler_get_decoration(fsCompiler, list[0].id, SpvDecorationLocation) != 0) {
        NSLog(@"fragment shader output must use (location = 0)");
        return NO;
    }

#define CHECK_SIZE(RES, TYPE, ERR) list_size = 0; \
    spvc_resources_get_resource_list_for_type(RES, TYPE, &list, &list_size); \
    if (list_size > 1) { \
        NSLog(ERR); \
        return NO; \
    }

    CHECK_SIZE(vsResources, SPVC_RESOURCE_TYPE_UNIFORM_BUFFER, @"vertex shader must use zero or one uniform buffer")
    spvc_reflected_resource const *vertexUBO = list_size == 0 ? nil : &list[0];
    CHECK_SIZE(vsResources, SPVC_RESOURCE_TYPE_PUSH_CONSTANT, @"vertex shader must use zero or one push constant buffer")
    spvc_reflected_resource const *vertexPush = list_size == 0 ? nil : &list[0];
    CHECK_SIZE(fsResources, SPVC_RESOURCE_TYPE_UNIFORM_BUFFER, @"fragment shader must use zero or one uniform buffer")
    spvc_reflected_resource const *fragmentUBO = list_size == 0 ? nil : &list[0];
    CHECK_SIZE(fsResources, SPVC_RESOURCE_TYPE_PUSH_CONSTANT, @"fragment shader must use zero or one push constant buffer")
    spvc_reflected_resource const *fragmentPush = list_size == 0 ? nil : &list[0];

#undef CHECK_SIZE

    if (vertexUBO && spvc_compiler_get_decoration(vsCompiler, vertexUBO->id, SpvDecorationDescriptorSet) != 0) {
        NSLog(@"vertex shader resources must use descriptor set #0");
        return NO;
    }
    if (fragmentUBO && spvc_compiler_get_decoration(fsCompiler, fragmentUBO->id, SpvDecorationDescriptorSet) != 0) {
        NSLog(@"fragment shader resources must use descriptor set #0");
        return NO;
    }

    unsigned vertexUBOBinding = vertexUBO ? spvc_compiler_get_decoration(vsCompiler, vertexUBO->id, SpvDecorationBinding) : -1u;
    unsigned fragmentUBOBinding = fragmentUBO ? spvc_compiler_get_decoration(fsCompiler, fragmentUBO->id, SpvDecorationBinding) : -1u;
    if (vertexUBOBinding != -1u &&
        fragmentUBOBinding != -1u &&
        vertexUBOBinding != fragmentUBOBinding) {
        NSLog(@"vertex and fragment shader uniform buffers must have same binding");
        return NO;
    }

    unsigned uboBinding = vertexUBOBinding != -1u ? vertexUBOBinding : fragmentUBOBinding;

    const NSUInteger MAX_BINDINGS = 16;

    bool hasUBO = vertexUBO || fragmentUBO;
    if (hasUBO && uboBinding >= MAX_BINDINGS) {
        NSLog(@"%u bindings exceeds max of %lu", uboBinding, MAX_BINDINGS);
        return NO;
    }

    ref.uboBinding = hasUBO ? uboBinding : 0;

    if (vertexUBO) {
        ref.uboStageUsage = StageUsageVertex;
        size_t sz = 0;
        spvc_compiler_get_declared_struct_size(vsCompiler, spvc_compiler_get_type_handle(vsCompiler, vertexUBO->base_type_id), &sz);
        ref.uboSize = sz;
    }

    if (vertexPush) {
        ref.pushStageUsage = StageUsageVertex;
        size_t sz = 0;
        spvc_compiler_get_declared_struct_size(vsCompiler, spvc_compiler_get_type_handle(vsCompiler, vertexPush->base_type_id), &sz);
        ref.pushSize = sz;
    }

    if (fragmentUBO) {
        ref.uboStageUsage |= StageUsageFragment;
        size_t sz = 0;
        spvc_compiler_get_declared_struct_size(fsCompiler, spvc_compiler_get_type_handle(fsCompiler, fragmentUBO->base_type_id), &sz);
        ref.uboSize = MAX(ref.uboSize, sz);
    }

    if (fragmentPush) {
        ref.pushStageUsage |= StageUsageFragment;
        size_t sz = 0;
        spvc_compiler_get_declared_struct_size(fsCompiler, spvc_compiler_get_type_handle(fsCompiler, fragmentPush->base_type_id), &sz);
        ref.pushSize = MAX(ref.pushSize, sz);
    }

    /* Find all relevant uniforms and push constants. */
    if (vertexUBO && ![self addActiveBufferRanges:ref compiler:vsCompiler resource:vertexUBO ubo:YES])
        return NO;
    if (fragmentUBO && ![self addActiveBufferRanges:ref compiler:fsCompiler resource:fragmentUBO ubo:YES])
        return NO;
    if (vertexPush && ![self addActiveBufferRanges:ref compiler:vsCompiler resource:vertexPush ubo:NO])
        return NO;
    if (fragmentPush && ![self addActiveBufferRanges:ref compiler:fsCompiler resource:fragmentPush ubo:NO])
        return NO;

    NSUInteger bindings = hasUBO ? (1u << uboBinding) : 0;
    spvc_resources_get_resource_list_for_type(fsResources, SPVC_RESOURCE_TYPE_SAMPLED_IMAGE, &list, &list_size);
    for (NSUInteger i = 0; i < list_size; i++) {
        spvc_reflected_resource const *tex = &list[i];

        if (spvc_compiler_get_decoration(fsCompiler, tex->id, SpvDecorationDescriptorSet) != 0) {
            NSLog(@"fragment shader texture must use descriptor set #0");
            return NO;
        }

        NSUInteger binding = spvc_compiler_get_decoration(fsCompiler, tex->id, SpvDecorationBinding);
        if (binding >= MAX_BINDINGS) {
            NSLog(@"fragment shader texture binding exceeds %lu", MAX_BINDINGS);
            return NO;
        }

        if (bindings & (1u << binding)) {
            NSLog(@"fragment shader texture binding %lu already in use", binding);
            return NO;
        }

        bindings |= (1u << binding);

        ShaderTextureSemanticMap *sem = [ref textureSemanticForName:[NSString stringWithUTF8String:tex->name]];
        if (sem == nil) {
            NSLog(@"invalid texture");
        }

        [ref setBinding:binding forTextureSemantic:sem.semantic atIndex:sem.index];
    }

    // print out some debug info

    NSLog(@"%@", ref.debugDescription);

    return YES;
}

- (BOOL)validateType:(spvc_type)type forSemantic:(OEShaderBufferSemantic)semantic {
    if (spvc_type_get_num_array_dimensions(type) > 0) {
        return NO;
    }
    spvc_basetype bt = spvc_type_get_basetype(type);
    if (bt != SPVC_BASETYPE_FP32 && bt != SPVC_BASETYPE_INT32 && bt != SPVC_BASETYPE_UINT32) {
        return NO;
    }

    unsigned vecsz = spvc_type_get_vector_size(type);
    unsigned cols = spvc_type_get_columns(type);

    if ([semantic isEqualToString:OEShaderBufferSemanticMVP]) {
        return bt == SPVC_BASETYPE_FP32 && vecsz == 4 && cols == 4;
    }

    if ([semantic isEqualToString:OEShaderBufferSemanticFrameCount]) {
        return bt == SPVC_BASETYPE_UINT32 && vecsz == 1 && cols == 1;
    }

    if ([semantic isEqualToString:OEShaderBufferSemanticFloatParameter]) {
        return bt == SPVC_BASETYPE_FP32 && vecsz == 1 && cols == 1;
    }

    // all other semantics (Size) are vec4
    return bt == SPVC_BASETYPE_FP32 && vecsz == 4 && cols == 1;
}

- (BOOL)validateType:(spvc_type)type forTextureSemantic:(OEShaderTextureSemantic)semantic {
    if (spvc_type_get_num_array_dimensions(type) > 0) {
        return NO;
    }
    spvc_basetype bt = spvc_type_get_basetype(type);

    // vec4 Size types
    return bt == SPVC_BASETYPE_FP32 && spvc_type_get_vector_size(type) == 4 && spvc_type_get_columns(type) == 1;
}

- (BOOL)addActiveBufferRanges:(ShaderReflection *)ref compiler:(spvc_compiler)compiler
                     resource:(spvc_reflected_resource const *)res ubo:(BOOL)ubo {

    spvc_buffer_range const *ranges;
    size_t num_ranges = 0;
    spvc_compiler_get_active_buffer_ranges(compiler, res->id, &ranges, &num_ranges);
    for (size_t i = 0; i < num_ranges; i++) {
        spvc_buffer_range const *range = &ranges[i];
        char const *name = spvc_compiler_get_member_name(compiler, res->base_type_id, range->index);
        spvc_type type = spvc_compiler_get_type_handle(compiler, spvc_type_get_member_type(spvc_compiler_get_type_handle(compiler, res->base_type_id), range->index));

        ShaderSemanticMap *bufferSem = [ref bufferSemanticForUniformName:[NSString stringWithUTF8String:name]];
        ShaderTextureSemanticMap *texSem = [ref textureSemanticForUniformName:[NSString stringWithUTF8String:name]];

        if (texSem.semantic == OEShaderTextureSemanticPassOutput && texSem.index >= ref.passNumber) {
            NSLog(@"shader pass #%lu is attempting to use output from self or later pass #%lu", ref.passNumber, texSem.index);
            return NO;
        }

        unsigned vecsz = spvc_type_get_vector_size(type);
        unsigned cols = spvc_type_get_columns(type);

        if (bufferSem) {
            if (![self validateType:type forSemantic:bufferSem.semantic]) {
                NSLog(@"invalid type for %s", name);
                return NO;
            }

            if ([bufferSem.semantic isEqualToString:OEShaderBufferSemanticFloatParameter]) {
                if (![ref setOffset:range->offset vecSize:vecsz forFloatParameterAtIndex:bufferSem.index ubo:ubo]) {
                    return NO;
                }
            } else {
                if (![ref setOffset:range->offset vecSize:vecsz * cols forSemantic:bufferSem.semantic ubo:ubo]) {
                    return NO;
                }
            }
        } else if (texSem) {
            if (![self validateType:type forTextureSemantic:texSem.semantic]) {
                NSLog(@"invalid type for %s; expected a vec4", name);
                return NO;
            }

            if (![ref setOffset:range->offset forTextureSemantic:texSem.semantic atIndex:texSem.index ubo:ubo]) {
                return NO;
            }
        }
    }
    return YES;
}

@end
