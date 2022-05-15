//
// Created by Stuart Carnie on 2019-05-17.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#import "OEShaderPassCompiler.h"
#import <CSPIRVCross/CSPIRVCross.h>
#import "SlangCompiler.h"
#import "ShaderReflection.h"
#import "ShaderPassSemantics.h"
#import <OpenEmuShaders/OpenEmuShaders-Swift.h>
#import "OESourceParser+Private.h"
#import "OELogging.h"

@implementation OEShaderPassCompiler
{
    SlangShader                     *_shader;
    NSArray<ShaderPassBindings *>   *_bindings;
}

- (instancetype)initWithShaderModel:(SlangShader *)shader
{
    self = [super init];
    
    _shader = shader;
    
    NSUInteger c = shader.passes.count;
    NSMutableArray<ShaderPassBindings *> *bindings = [NSMutableArray arrayWithCapacity:c];
    while (c > 0)
    {
        [bindings addObject:[ShaderPassBindings new]];
        c--;
    }
    
    _bindings = bindings;
    
    return self;
}

// typedef void (*spvc_error_callback)(void *userdata, const char *error);

void error_callback(void *userdata, const char *error)
{
    OEShaderPassCompiler *compiler = (__bridge OEShaderPassCompiler *)userdata;
    [compiler compileError:error];
}

- (void)compileError:(char const *)error
{
    // TODO(sgc): handle callback errors
    os_log_error(OE_LOG_DEFAULT, "error from SPIR-V compiler: %{public}s", error);
}

- (NSData *)irForPass:(ShaderPass *)pass ofType:(ShaderType)type options:(ShaderCompilerOptions *)options error:(NSError **)error
{
    NSData *data = nil;
    NSURL *filename = nil;
    
    if (options.isCacheDisabled == NO)
    {
        NSURL *cacheDir = options.cacheDir;
        [NSFileManager.defaultManager createDirectoryAtURL:cacheDir withIntermediateDirectories:YES attributes:nil error:nil];
        
        NSString *version = [[NSBundle bundleForClass:self.class].infoDictionary objectForKey:@"CFBundleShortVersionString"];
        
        NSString *vorf  = type == ShaderTypeVertex ? @"vert" : @"frag";
        NSString *file  = [NSString stringWithFormat:@"%@.%@.%@.%@.spirv", pass.source.basename, pass.source.sha256, version.versionValue, vorf];
        filename = [cacheDir URLByAppendingPathComponent:file];
        data = [NSData dataWithContentsOfURL:filename];
    }
    
    if (data == nil)
    {
        NSString *source = type == ShaderTypeVertex ? pass.source.vertexSource : pass.source.fragmentSource;
        SlangCompiler *c = [SlangCompiler new];
        NSError *err;
        ShaderProgram *prog = [c compileSource:source ofType:type error:&err];
        if (prog == nil || err != nil) {
            if (error != nil)
            {
                *error = err;
            }
            return nil;
        }
        
        data = [NSData dataWithBytes:(void *)prog.spirv length:prog.spirvLengthBytes];
        
        if (filename != nil)
        {
            [data writeToURL:filename atomically:YES];
        }
    }
    
    return data;
}

- (BOOL)makeCompilersForPass:(ShaderPass *)pass
                     context:(spvc_context)ctx
                     options:(ShaderCompilerOptions *)options
              vertexCompiler:(spvc_compiler *)vsCompiler
            fragmentCompiler:(spvc_compiler *)fsCompiler
                       error:(NSError **)error
{
    unsigned int version = 0;
    switch (options.languageVersion) {
        case MTLLanguageVersion2_4:
            version = SPVC_MAKE_MSL_VERSION(2, 4, 0);
            break;
        
        case MTLLanguageVersion2_3:
            version = SPVC_MAKE_MSL_VERSION(2, 3, 0);
            break;
        
        case MTLLanguageVersion2_2:
            version = SPVC_MAKE_MSL_VERSION(2, 2, 0);
            break;

        // default to Metal Version 2.1
        case MTLLanguageVersion2_1:
        default:
            version = SPVC_MAKE_MSL_VERSION(2, 1, 0);
            break;
    }
    
    NSError *err;
    NSData *data = [self irForPass:pass ofType:ShaderTypeVertex options:options error:&err];
    if (err != nil)
    {
        if (error != nil)
        {
            *error = err;
        }
        
        os_log_error(OE_LOG_DEFAULT, "error compiling vertex shader program '%@': %@", pass.url.absoluteString, err.localizedDescription);
        return NO;
    }
    
    spvc_parsed_ir vsIR = nil;
    spvc_context_parse_spirv(ctx, data.bytes, data.length / sizeof(SpvId), &vsIR);
    if (vsIR == nil) {
        os_log_error(OE_LOG_DEFAULT, "error parsing vertex spirv '%@'", pass.url.absoluteString);
        return NO;
    }
    
    spvc_context_create_compiler(ctx, SPVC_BACKEND_MSL, vsIR, SPVC_CAPTURE_MODE_TAKE_OWNERSHIP, vsCompiler);
    if (*vsCompiler == nil) {
        os_log_error(OE_LOG_DEFAULT, "error creating vertex compiler '%@'", pass.url.absoluteString);
        return NO;
    }
    
    // vertex compile
    spvc_compiler_options vsOptions;
    spvc_compiler_create_compiler_options(*vsCompiler, &vsOptions);
    spvc_compiler_options_set_uint(vsOptions, SPVC_COMPILER_OPTION_MSL_VERSION, (unsigned int)version);
    spvc_compiler_install_compiler_options(*vsCompiler, vsOptions);
    
    // fragment shader
    data = [self irForPass:pass ofType:ShaderTypeFragment options:options error:&err];
    if (err != nil)
    {
        if (error != nil)
        {
            *error = err;
        }
        os_log_error(OE_LOG_DEFAULT, "error compiling fragment shader program '%@': %@", pass.url.absoluteString, err.localizedFailureReason);
        return NO;
    }
    
    spvc_parsed_ir fsIR = nil;
    spvc_context_parse_spirv(ctx, data.bytes, data.length / sizeof(SpvId), &fsIR);
    if (fsIR == nil) {
        os_log_error(OE_LOG_DEFAULT, "error parsing fragment spirv '%@'", pass.url.absoluteString);
        return NO;
    }
    
    spvc_context_create_compiler(ctx, SPVC_BACKEND_MSL, fsIR, SPVC_CAPTURE_MODE_TAKE_OWNERSHIP, fsCompiler);
    if (*fsCompiler == nil) {
        os_log_error(OE_LOG_DEFAULT, "error creating fragment compiler '%@'", pass.url.absoluteString);
        return NO;
    }
    
    // fragment compiler
    spvc_compiler_options fsOptions;
    spvc_compiler_create_compiler_options(*fsCompiler, &fsOptions);
    spvc_compiler_options_set_uint(fsOptions, SPVC_COMPILER_OPTION_MSL_VERSION, (unsigned int)version);
    spvc_compiler_install_compiler_options(*fsCompiler, fsOptions);
    
    return YES;
}

- (BOOL)buildPass:(NSUInteger)passNumber
          options:(ShaderCompilerOptions *)options
    passSemantics:(ShaderPassSemantics *)passSemantics
           vertex:(NSString **)vsrc
         fragment:(NSString **)fsrc
            error:(NSError **)error
{
    spvc_context ctx;
    spvc_context_create(&ctx);
    spvc_context_set_error_callback(ctx, error_callback, (__bridge void *)self);
    
    @try {
        ShaderPass *pass = _shader.passes[passNumber];
        ShaderPassBindings *passBindings = _bindings[passNumber];
        passBindings.format = pass.format;

        spvc_compiler vsCompiler, fsCompiler;
        if ([self makeCompilersForPass:pass context:ctx options:options
                        vertexCompiler:&vsCompiler fragmentCompiler:&fsCompiler
                                 error:error] == NO)
        {
            return NO;
        }
        
        char const *vsCode;
        spvc_compiler_compile(vsCompiler, &vsCode);
        *vsrc = [NSString stringWithUTF8String:vsCode];
        
        char const *fsCode;
        spvc_compiler_compile(fsCompiler, &fsCode);
        *fsrc = [NSString stringWithUTF8String:fsCode];
        
        if (passSemantics == nil)
        {
            // optional value, when null means just generate the source
            return YES;
        }

        return [self processPass:passNumber
              withVertexCompiler:vsCompiler
                fragmentCompiler:fsCompiler
                   passSemantics:passSemantics
                    passBindings:passBindings];
    } @finally {
        spvc_context_destroy(ctx);
    }
}

- (BOOL)processPass:(NSUInteger)passNumber
 withVertexCompiler:(spvc_compiler)vsCompiler
   fragmentCompiler:(spvc_compiler)fsCompiler
      passSemantics:(ShaderPassSemantics *)passSemantics
       passBindings:(ShaderPassBindings *)passBindings
{
    
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
    
    if (![self reflectWith:ref withVertexCompiler:vsCompiler fragmentCompiler:fsCompiler]) {
        // TODO(sgc): unable to reflect SPIR-V program data
        os_log_error(OE_LOG_DEFAULT, "reflect failed");
        return NO;
    }
    
    // UBO
    ShaderPassBufferBinding *uboB = passBindings.buffers[0];
    uboB.stageUsage  = ref.uboStageUsage;
    uboB.bindingVert = ref.uboBindingVert;
    uboB.bindingFrag = ref.uboBindingFrag;
    uboB.size        = (ref.uboSize + 0xf) & ~0xf; // round up to nearest 16 bytes
    
    // push constants
    ShaderPassBufferBinding *pshB = passBindings.buffers[1];
    pshB.stageUsage  = ref.pushStageUsage;
    pshB.bindingVert = ref.pushBindingVert;
    pshB.bindingFrag = ref.pushBindingFrag;
    pshB.size        = (ref.pushSize + 0xf) & ~0xf; // round up to nearest 16 bytes
    
    for (OEShaderBufferSemantic sem in ref.semantics) {
        ShaderSemanticMeta *meta = ref.semantics[sem];
        NSString           *name = [ref nameForBufferSemantic:sem index:0];
        if (meta.uboActive) {
            [uboB addUniformData:passSemantics.uniforms[sem].data
                            size:meta.numberOfComponents * sizeof(float)
                          offset:meta.uboOffset
                            name:name];
        }
        if (meta.pushActive) {
            [pshB addUniformData:passSemantics.uniforms[sem].data
                            size:meta.numberOfComponents * sizeof(float)
                          offset:meta.pushOffset
                            name:name];
        }
    }
    
    NSUInteger              i = 0;
    for (ShaderSemanticMeta *meta in ref.floatParameters) {
        NSString          *name  = [ref nameForBufferSemantic:OEShaderBufferSemanticFloatParameter index:i];
        ShaderPassBufferSemantics *param = [passSemantics parameterAtIndex:i];
        if (meta.uboActive) {
            [uboB addUniformData:param.data
                            size:meta.numberOfComponents * sizeof(float)
                          offset:meta.uboOffset
                            name:name];
        }
        if (meta.pushActive) {
            [pshB addUniformData:param.data
                            size:meta.numberOfComponents * sizeof(float)
                          offset:meta.pushOffset
                            name:name];
        }
        i++;
    }
    
    for (OEShaderTextureSemantic sem in ref.textures) {
        NSArray<ShaderTextureSemanticMeta *> *a   = ref.textures[sem];
        ShaderPassTextureSemantics           *tex = passSemantics.textures[sem];
        
        NSUInteger                     index = 0;
        for (ShaderTextureSemanticMeta *meta in a) {
            if (meta.stageUsage != OEStageUsageNone) {
                ShaderPassTextureBinding *bind = [passBindings addTexture:(id<MTLTexture> __unsafe_unretained *)(void *)((uintptr_t)(void *)tex.texture + index * tex.textureStride)];
                
                if (sem == OEShaderTextureSemanticUser) {
                    bind.wrap   = _shader.luts[index].wrapMode;
                    bind.filter = _shader.luts[index].filter;
                } else {
                    bind.wrap   = _shader.passes[passNumber].wrapMode;
                    bind.filter = _shader.passes[passNumber].filter;
                }
                
                bind.stageUsage = meta.stageUsage;
                bind.binding    = meta.binding;
                bind.name       = [ref nameForTextureSemantic:sem index:index];
                
                if (sem == OEShaderTextureSemanticPassFeedback) {
                    _bindings[index].isFeedback = YES;
                } else if (sem == OEShaderTextureSemanticOriginalHistory && _historyCount < index) {
                    _historyCount = index;
                }
            }
            
            NSString *name = [ref sizeNameForTextureSemantic:sem index:0];
            if (meta.uboActive) {
                [uboB addUniformData:(void *)((uintptr_t)tex.textureSize + index * tex.sizeStride)
                                size:4 * sizeof(float)
                              offset:meta.uboOffset
                                name:name];
            }
            if (meta.pushActive) {
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
{
    spvc_resources vsResources = nil;
    spvc_compiler_create_shader_resources(vsCompiler, &vsResources);

    //spvc_set fsVariables = nil;
    //spvc_compiler_get_active_interface_variables(fsCompiler, &fsVariables);
    
    spvc_resources fsResources = nil;
    spvc_compiler_create_shader_resources(fsCompiler, &fsResources);
    //spvc_compiler_create_shader_resources_for_active_variables(fsCompiler, &fsResources, fsVariables);
    
    spvc_reflected_resource const *list;
    size_t                        list_size;
#define CHECK_EMPTY(RES, TYPE) list_size = 0; \
    spvc_resources_get_resource_list_for_type(RES, TYPE, &list, &list_size); \
    if (list_size > 0) { \
os_log_error(OE_LOG_DEFAULT, "unexpected resource type in shader %{public}@", @#TYPE); \
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
        os_log_error(OE_LOG_DEFAULT, "vertex shader input must have two attributes");
        return NO;
    }
    
    NSUInteger mask = 0;
    mask |= 1 << spvc_compiler_get_decoration(vsCompiler, list[0].id, SpvDecorationLocation);
    mask |= 1 << spvc_compiler_get_decoration(vsCompiler, list[1].id, SpvDecorationLocation);
    if (mask != 0x03) {
        os_log_error(OE_LOG_DEFAULT, "vertex shader input attributes must use (location = 0) and (location = 1)");
        return NO;
    }
    
    // validate number of render targets for fragment shader
    list_size = 0;
    spvc_resources_get_resource_list_for_type(fsResources, SPVC_RESOURCE_TYPE_STAGE_OUTPUT, &list, &list_size);
    if (list_size != 1) {
        os_log_error(OE_LOG_DEFAULT, "fragment shader must have a single output");
        return NO;
    }
    
    if (spvc_compiler_get_decoration(fsCompiler, list[0].id, SpvDecorationLocation) != 0) {
        os_log_error(OE_LOG_DEFAULT, "fragment shader output must use (location = 0)");
        return NO;
    }

#define CHECK_SIZE(RES, TYPE, ERR) list_size = 0; \
    spvc_resources_get_resource_list_for_type(RES, TYPE, &list, &list_size); \
    if (list_size > 1) { \
        os_log_error(OE_LOG_DEFAULT, ERR); \
        return NO; \
    }
    
    CHECK_SIZE(vsResources, SPVC_RESOURCE_TYPE_UNIFORM_BUFFER, "vertex shader must use zero or one uniform buffer")
    spvc_reflected_resource const *vertexUBO = list_size == 0 ? nil : &list[0];
    CHECK_SIZE(vsResources, SPVC_RESOURCE_TYPE_PUSH_CONSTANT, "vertex shader must use zero or one push constant buffer")
    spvc_reflected_resource const *vertexPush = list_size == 0 ? nil : &list[0];
    CHECK_SIZE(fsResources, SPVC_RESOURCE_TYPE_UNIFORM_BUFFER, "fragment shader must use zero or one uniform buffer")
    spvc_reflected_resource const *fragmentUBO = list_size == 0 ? nil : &list[0];
    CHECK_SIZE(fsResources, SPVC_RESOURCE_TYPE_PUSH_CONSTANT, "fragment shader must use zero or one push constant buffer")
    spvc_reflected_resource const *fragmentPush = list_size == 0 ? nil : &list[0];

#undef CHECK_SIZE
    
    if (vertexUBO && spvc_compiler_get_decoration(vsCompiler, vertexUBO->id, SpvDecorationDescriptorSet) != 0) {
        os_log_error(OE_LOG_DEFAULT, "vertex shader resources must use descriptor set #0");
        return NO;
    }
    if (fragmentUBO && spvc_compiler_get_decoration(fsCompiler, fragmentUBO->id, SpvDecorationDescriptorSet) != 0) {
        os_log_error(OE_LOG_DEFAULT, "fragment shader resources must use descriptor set #0");
        return NO;
    }

    unsigned vertexUBOBinding   = vertexUBO   ? spvc_compiler_msl_get_automatic_resource_binding(vsCompiler, vertexUBO->id)   : -1u;
    unsigned fragmentUBOBinding = fragmentUBO ? spvc_compiler_msl_get_automatic_resource_binding(fsCompiler, fragmentUBO->id) : -1u;
    bool hasVertUBO  = vertexUBO   && (vertexUBOBinding   != -1u);
    bool hasFragUBO  = fragmentUBO && (fragmentUBOBinding != -1u);
    ref.uboBindingVert = hasVertUBO ? vertexUBOBinding   : 0;
    ref.uboBindingFrag = hasFragUBO ? fragmentUBOBinding : 0;

    unsigned vertexPushBinding   = vertexPush   ? spvc_compiler_msl_get_automatic_resource_binding(vsCompiler, vertexPush->id)   : -1u;
    unsigned fragmentPushBinding = fragmentPush ? spvc_compiler_msl_get_automatic_resource_binding(fsCompiler, fragmentPush->id) : -1u;
    bool hasVertPush = vertexPush   && (vertexPushBinding   != -1u);
    bool hasFragPush = fragmentPush && (fragmentPushBinding != -1u);
    ref.pushBindingVert = hasVertPush ? vertexPushBinding   : 0;
    ref.pushBindingFrag = hasFragPush ? fragmentPushBinding : 0;

    
    if (hasVertUBO) {
        ref.uboStageUsage = OEStageUsageVertex;
        size_t sz = 0;
        spvc_compiler_get_declared_struct_size(vsCompiler, spvc_compiler_get_type_handle(vsCompiler, vertexUBO->base_type_id), &sz);
        ref.uboSize = sz;
    }
    
    if (hasVertPush) {
        ref.pushStageUsage = OEStageUsageVertex;
        size_t sz = 0;
        spvc_compiler_get_declared_struct_size(vsCompiler, spvc_compiler_get_type_handle(vsCompiler, vertexPush->base_type_id), &sz);
        ref.pushSize = sz;
    }
    
    if (hasFragUBO) {
        ref.uboStageUsage |= OEStageUsageFragment;
        size_t sz = 0;
        spvc_compiler_get_declared_struct_size(fsCompiler, spvc_compiler_get_type_handle(fsCompiler, fragmentUBO->base_type_id), &sz);
        ref.uboSize = MAX(ref.uboSize, sz);
    }
    
    if (hasFragPush) {
        ref.pushStageUsage |= OEStageUsageFragment;
        size_t sz = 0;
        spvc_compiler_get_declared_struct_size(fsCompiler, spvc_compiler_get_type_handle(fsCompiler, fragmentPush->base_type_id), &sz);
        ref.pushSize = MAX(ref.pushSize, sz);
    }
    
    /* Find all relevant uniforms and push constants. */
    if (hasVertUBO && ![self addActiveBufferRanges:ref compiler:vsCompiler resource:vertexUBO ubo:YES])
        return NO;
    if (hasFragUBO && ![self addActiveBufferRanges:ref compiler:fsCompiler resource:fragmentUBO ubo:YES])
        return NO;
    if (hasVertPush && ![self addActiveBufferRanges:ref compiler:vsCompiler resource:vertexPush ubo:NO])
        return NO;
    if (hasFragPush && ![self addActiveBufferRanges:ref compiler:fsCompiler resource:fragmentPush ubo:NO])
        return NO;
    
    NSUInteger bindings = 0;
    spvc_resources_get_resource_list_for_type(fsResources, SPVC_RESOURCE_TYPE_SAMPLED_IMAGE, &list, &list_size);
    for (NSUInteger i = 0; i < list_size; i++) {
        spvc_reflected_resource const *tex = &list[i];
        
        if (spvc_compiler_get_decoration(fsCompiler, tex->id, SpvDecorationDescriptorSet) != 0) {
            os_log_error(OE_LOG_DEFAULT, "fragment shader texture must use descriptor set #0");
            return NO;
        }
        
        NSUInteger binding = spvc_compiler_msl_get_automatic_resource_binding(fsCompiler, tex->id);
        if (binding == -1u) {
            // no binding
            continue;
        }
        
        if (binding >= kMaxShaderBindings) {
            os_log_error(OE_LOG_DEFAULT, "fragment shader texture binding exceeds %d", kMaxShaderBindings);
            return NO;
        }
        
        if (bindings & (1u << binding)) {
            os_log_error(OE_LOG_DEFAULT, "fragment shader texture binding %lu already in use", binding);
            return NO;
        }
        
        bindings |= (1u << binding);
        
        ShaderTextureSemanticMap *sem = [ref textureSemanticForName:[NSString stringWithUTF8String:tex->name]];
        if (sem == nil) {
            os_log_error(OE_LOG_DEFAULT, "invalid texture %{public}s", tex->name);
            return NO;
        }
        
        [ref setBinding:binding forTextureSemantic:sem.semantic atIndex:sem.index];
    }
    
    // print out some debug info
    
    os_log_debug(OE_LOG_DEFAULT, "%{public}@", ref.debugDescription);
    
    return YES;
}

- (BOOL)validateType:(spvc_type)type forSemantic:(OEShaderBufferSemantic)semantic
{
    if (spvc_type_get_num_array_dimensions(type) > 0) {
        return NO;
    }
    spvc_basetype bt = spvc_type_get_basetype(type);
    if (bt != SPVC_BASETYPE_FP32 && bt != SPVC_BASETYPE_INT32 && bt != SPVC_BASETYPE_UINT32) {
        return NO;
    }
    
    unsigned vecsz = spvc_type_get_vector_size(type);
    unsigned cols  = spvc_type_get_columns(type);
    
    if ([semantic isEqualToString:OEShaderBufferSemanticMVP]) {
        return bt == SPVC_BASETYPE_FP32 && vecsz == 4 && cols == 4;
    }
    
    if ([semantic isEqualToString:OEShaderBufferSemanticFrameCount]) {
        return bt == SPVC_BASETYPE_UINT32 && vecsz == 1 && cols == 1;
    }

    if ([semantic isEqualToString:OEShaderBufferSemanticFrameDirection]) {
        return bt == SPVC_BASETYPE_INT32 && vecsz == 1 && cols == 1;
    }

    if ([semantic isEqualToString:OEShaderBufferSemanticFloatParameter]) {
        return bt == SPVC_BASETYPE_FP32 && vecsz == 1 && cols == 1;
    }
    
    // all other semantics (Size) are vec4
    return bt == SPVC_BASETYPE_FP32 && vecsz == 4 && cols == 1;
}

- (BOOL)validateType:(spvc_type)type forTextureSemantic:(OEShaderTextureSemantic)semantic
{
    if (spvc_type_get_num_array_dimensions(type) > 0) {
        return NO;
    }
    spvc_basetype bt = spvc_type_get_basetype(type);
    
    // vec4 Size types
    return bt == SPVC_BASETYPE_FP32 && spvc_type_get_vector_size(type) == 4 && spvc_type_get_columns(type) == 1;
}

- (BOOL)addActiveBufferRanges:(ShaderReflection *)ref compiler:(spvc_compiler)compiler
                     resource:(spvc_reflected_resource const *)res ubo:(BOOL)ubo
{
    
    spvc_buffer_range const *ranges;
    size_t                  num_ranges = 0;
    spvc_compiler_get_active_buffer_ranges(compiler, res->id, &ranges, &num_ranges);
    for (size_t i = 0; i < num_ranges; i++) {
        spvc_buffer_range const *range = &ranges[i];
        char const              *name  = spvc_compiler_get_member_name(compiler, res->base_type_id, range->index);
        spvc_type               type   = spvc_compiler_get_type_handle(compiler, spvc_type_get_member_type(spvc_compiler_get_type_handle(compiler, res->base_type_id), range->index));
        
        ShaderSemanticMap        *bufferSem = [ref bufferSemanticForUniformName:[NSString stringWithUTF8String:name]];
        ShaderTextureSemanticMap *texSem    = [ref textureSemanticForUniformName:[NSString stringWithUTF8String:name]];
        
        if (texSem.semantic == OEShaderTextureSemanticPassOutput && texSem.index >= ref.passNumber) {
            os_log_error(OE_LOG_DEFAULT, "shader pass #%lu is attempting to use output from self or later pass #%lu", ref.passNumber, texSem.index);
            return NO;
        }
        
        unsigned vecsz = spvc_type_get_vector_size(type);
        unsigned cols  = spvc_type_get_columns(type);
        
        if (bufferSem) {
            if (![self validateType:type forSemantic:bufferSem.semantic]) {
                os_log_error(OE_LOG_DEFAULT, "invalid type for %{public}s", name);
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
                os_log_error(OE_LOG_DEFAULT, "invalid type for %{public}s; expected a vec4", name);
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
