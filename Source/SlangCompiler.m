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

#import "OEEnums.h"
#import "SlangCompiler.h"
#import <CGLSLang/CGLSLang.h>
#import <CSPIRVTools/CSPIRVTools.h>
#include "OELogging.h"


@interface ShaderProgram()
- (instancetype)initWithData:(NSData *)spirv;
@end

@implementation SlangCompiler

- (instancetype)init
{
    self = [super init];
    
    return self;
}

- (ShaderProgram *)compileSource:(NSString *)source ofType:(ShaderType)type error:(NSError **)error
{
    switch (type)
    {
        case ShaderTypeVertex:
            return [self compileSPIRV:source stage:GLSLANG_STAGE_VERTEX error:error];
        case ShaderTypeFragment:
            return [self compileSPIRV:source stage:GLSLANG_STAGE_FRAGMENT error:error];
    }
}

- (ShaderProgram *)compileSPIRV:(NSString *)src stage:(glslang_stage_t)stage error:(NSError **)error
{
    const int DEFAULT_VERSION = 110;

    const char * code = src.UTF8String;
    glslang_input_t inp = {
        .language                   = GLSLANG_SOURCE_GLSL,
        .stage                      = stage,
        .client                     = GLSLANG_CLIENT_VULKAN,
        .client_version             = GLSLANG_TARGET_VULKAN_1_1,
        .target_language            = GLSLANG_TARGET_SPV,
        .target_language_version    = GLSLANG_TARGET_SPV_1_5,
        .code                       = code,
        .default_version            = DEFAULT_VERSION,
        .default_profile            = GLSLANG_NO_PROFILE,
        .force_default_version_and_profile = false,
        .forward_compatible         = false,
        .messages                   = GLSLANG_MSG_DEFAULT_BIT | GLSLANG_MSG_VULKAN_RULES_BIT | GLSLANG_MSG_SPV_RULES_BIT,
        .resource                   = glslang_get_default_resource(),
        .includer_type              = GLSLANG_INCLUDER_TYPE_FORBID,
        .includer                   = nil,
        .includer_context           = nil,
    };
    
    glslang_shader shader = glslang_shader_create(&inp);
    
    if (!glslang_shader_preprocess(shader, &inp))
    {
        const char * msg = glslang_shader_get_preprocessed_code(shader);
        if (error != nil)
        {
            // skipped modern syntax here as it was breaking Xcode
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      NSLocalizedString(@"Failed to preprocess shader", @"Shader failed to compile"), NSLocalizedDescriptionKey,
                                      @(msg), NSLocalizedFailureReasonErrorKey,
                                      nil];
            *error = [NSError errorWithDomain:OEShaderErrorDomain
                                         code:OEShaderCompilePreprocessError
                                     userInfo:userInfo];
        }
    
        os_log_error(OE_LOG_DEFAULT, "error preprocessing shader: %{public}s", msg);
        return nil;
    }
    
    if (!glslang_shader_parse(shader, &inp))
    {
        const char * infoLog = glslang_shader_get_info_log(shader);
        if (error != nil)
        {
            // skipped modern syntax here as it was breaking Xcode
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      NSLocalizedString(@"Failed to parse shader", @"Shader failed to compile"), NSLocalizedDescriptionKey,
                                      @(infoLog), NSLocalizedFailureReasonErrorKey,
                                      nil];
            *error = [NSError errorWithDomain:OEShaderErrorDomain
                                         code:OEShaderCompileParseError
                                     userInfo:userInfo];
        }
        
        os_log_error(OE_LOG_DEFAULT, "error parsing shader info log: %{public}s", infoLog);
        return nil;
    }
    
    glslang_program program = glslang_program_create();
    glslang_program_add_shader(program, shader);
    
    if (!glslang_program_link(program, inp.messages))
    {
        const char * infoLog = glslang_program_get_info_log(program);
        const char * infoDebugLog = glslang_program_get_info_debug_log(program);
        if (error != nil)
        {
            // skipped modern syntax here as it was breaking Xcode
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      NSLocalizedString(@"Failed to link shader", @"Shader failed to compile"), NSLocalizedDescriptionKey,
                                      @(infoLog), NSLocalizedFailureReasonErrorKey,
                                      nil];
            *error = [NSError errorWithDomain:OEShaderErrorDomain
                                         code:OEShaderCompileLinkError
                                     userInfo:userInfo];
        }
        
        os_log_error(OE_LOG_DEFAULT, "error linking shader info log: %{public}s", infoLog);
        os_log_error(OE_LOG_DEFAULT, "error linking shader info debug log: %{public}s", infoDebugLog);
        return nil;
    }
    
    glslang_program_SPIRV_generate(program, stage);
    
    spvt_optimizer opt = spvt_optimizer_create(SPV_TARGET_ENV_UNIVERSAL_1_5);
    spvt_optimizer_register_ccp_pass(opt);
    spvt_optimizer_register_dead_branch_elim_pass(opt);
    spvt_optimizer_register_aggressive_dce_pass(opt);
    spvt_optimizer_register_ssa_rewrite_pass(opt);
    spvt_optimizer_register_aggressive_dce_pass(opt);
    spvt_optimizer_register_eliminate_dead_constant_pass(opt);
    spvt_optimizer_register_aggressive_dce_pass(opt);
    
    uint32_t ** spirv           = nil;
    size_t      spirv_len_bytes = 0;
    
    spvt_vector vec = spvt_optimizer_run(opt, glslang_program_SPIRV_get_ptr(program), glslang_program_SPIRV_get_size(program));
    if (vec != nil)
    {
        spirv_len_bytes = spvt_vector_get_size(vec);
        spirv = (uint32_t **)malloc(spirv_len_bytes);
        memcpy(spirv, spvt_vector_get_ptr(vec), spirv_len_bytes);
        spvt_vector_destroy(vec);
    }
    else
    {
        spirv_len_bytes = glslang_program_SPIRV_get_size(program) * sizeof(unsigned int);
        spirv = (uint32_t **)malloc(spirv_len_bytes);
        glslang_program_SPIRV_get(program, (unsigned int *)spirv);
    }
    
    NSData *data = [[NSData alloc] initWithBytesNoCopy:spirv length:spirv_len_bytes freeWhenDone:YES];
    
    return [[ShaderProgram alloc] initWithData:data];
}

@end

@implementation ShaderProgram
{
    NSData *_spirv;
}

- (instancetype)initWithData:(NSData *)spirv
{
    self = [super init];
    
    _spirv = spirv;
    
    return self;
}

- (SpvId const *)spirv
{
    return (SpvId const *)_spirv.bytes;
}

- (size_t)spirvLength
{
    return _spirv.length / sizeof(uint32_t);
}

- (size_t)spirvLengthBytes
{
    return _spirv.length;
}

@end

