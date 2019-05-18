//
// Created by Stuart Carnie on 2019-05-17.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#import "OEShaderPassCompiler.h"
#import "spirv.h"
#import "spirv_cross_c.h"
#import "SlangShader.h"
#import "SlangCompiler.h"
#import "ShaderReflection.h"
#import "ShaderPassSemantics.h"
#import <OpenEmuShaders/OpenEmuShaders-Swift.h>
#import "OESourceParser+Private.h"

@implementation OEShaderPassCompiler {
    SlangShader __weak *_shader;
}

- (instancetype)initWithShaderModel:(SlangShader *)shader {
    self = [super init];

    _shader = shader;

    return self;
}

// typedef void (*spvc_error_callback)(void *userdata, const char *error);

void error_callback(void *userdata, const char *error) {
    OEShaderPassCompiler *compiler = (__bridge OEShaderPassCompiler *) userdata;
    [compiler compileError:error];
}

- (void)compileError:(char const *)error {
    // TODO(sgc): handle callback errors
}

- (BOOL)buildPass:(NSUInteger)passNumber
     metalVersion:(NSUInteger)version
    passSemantics:(ShaderPassSemantics *)passSemantics
     passBindings:(ShaderPassBindings *)passBindings
           vertex:(NSString **)vsrc
         fragment:(NSString **)fsrc {

    ShaderPass *pass = _shader.passes[passNumber];
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
        ShaderPass *pass = _shader.passes[i];
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

    for (NSUInteger i = 0; i < _shader.luts.count; i++) {
        ShaderLUT *lut = _shader.luts[i];
        if (![ref addTextureSemantic:OEShaderTextureSemanticUser passIndex:i name:lut.name]) {
            return NO;
        }
        if (![ref addTextureBufferSemantic:OEShaderTextureSemanticUser passIndex:i name:[lut.name stringByAppendingString:@"Size"]]) {
            return NO;
        }
    }

    for (NSUInteger i = 0; i < _shader.parameters.count; i++) {
        OEShaderParameter *param = _shader.parameters[i];
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
        OEShaderParameter *param = _shader.parameters[i];
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
            if (meta.stageUsage != OEStageUsageNone) {
                ShaderPassTextureBinding *bind = [passBindings addTexture:(id<MTLTexture> __unsafe_unretained *)(void *)((uintptr_t)(void *)tex.texture + index * tex.textureStride)];

                if (sem == OEShaderTextureSemanticUser) {
                    bind.wrap = _shader.luts[index].wrapMode;
                    bind.filter = _shader.luts[index].filter;
                } else {
                    bind.wrap = _shader.passes[passNumber].wrapMode;
                    bind.filter = _shader.passes[passNumber].filter;
                }

                bind.stageUsage = meta.stageUsage;
                bind.binding = meta.binding;
                bind.name = [ref nameForTextureSemantic:sem index:index];

                if (sem == OEShaderTextureSemanticPassFeedback) {
                    _shader.passes[index].isFeedback = YES;
                } else if (sem == OEShaderTextureSemanticOriginalHistory && _shader.historySize < index) {
                    _shader.historySize = index;
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

    bool hasUBO = vertexUBO || fragmentUBO;
    if (hasUBO && uboBinding >= kMaxShaderBindings) {
        NSLog(@"%u bindings exceeds max of %d", uboBinding, kMaxShaderBindings);
        return NO;
    }

    ref.uboBinding = hasUBO ? uboBinding : 0;

    if (vertexUBO) {
        ref.uboStageUsage = OEStageUsageVertex;
        size_t sz = 0;
        spvc_compiler_get_declared_struct_size(vsCompiler, spvc_compiler_get_type_handle(vsCompiler, vertexUBO->base_type_id), &sz);
        ref.uboSize = sz;
    }

    if (vertexPush) {
        ref.pushStageUsage = OEStageUsageVertex;
        size_t sz = 0;
        spvc_compiler_get_declared_struct_size(vsCompiler, spvc_compiler_get_type_handle(vsCompiler, vertexPush->base_type_id), &sz);
        ref.pushSize = sz;
    }

    if (fragmentUBO) {
        ref.uboStageUsage |= OEStageUsageFragment;
        size_t sz = 0;
        spvc_compiler_get_declared_struct_size(fsCompiler, spvc_compiler_get_type_handle(fsCompiler, fragmentUBO->base_type_id), &sz);
        ref.uboSize = MAX(ref.uboSize, sz);
    }

    if (fragmentPush) {
        ref.pushStageUsage |= OEStageUsageFragment;
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
        if (binding >= kMaxShaderBindings) {
            NSLog(@"fragment shader texture binding exceeds %d", kMaxShaderBindings);
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