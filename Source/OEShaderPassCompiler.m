//
// Created by Stuart Carnie on 2019-05-17.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#import "OEShaderPassCompiler.h"
#import <CSPIRVCross/CSPIRVCross.h>
#import "ShaderReflection.h"
#import "ShaderPassSemantics.h"
#import <OpenEmuShaders/OpenEmuShaders-Swift.h>
#import "OESourceParser+Private.h"
#import "OELogging.h"
#import <OpenEmuShaders/OEEnums.h>

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
