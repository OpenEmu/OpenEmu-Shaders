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

@end
