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
        data = [c compileSource:source ofType:type error:&err];
        if (data == nil || err != nil) {
            if (error != nil)
            {
                *error = err;
            }
            return nil;
        }
        
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

@end
