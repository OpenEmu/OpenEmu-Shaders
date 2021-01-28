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
#include "glslang/Public/ShaderLang.h"
#include "StandAlone/ResourceLimits.h"
#include "SPIRV/GlslangToSpv.h"
#include "OELogging.h"
#include "spirv-tools/libspirv.hpp"
#include "spirv-tools/optimizer.hpp"


using namespace glslang;
using namespace std;

@interface ShaderProgram()
- (instancetype)initWithVector:(shared_ptr<vector<uint32_t>>)spirv;
@end

@implementation SlangCompiler

+ (void)initialize
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        InitializeProcess();
    });
}

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
            return [self compileSPIRV:source language:EShLangVertex error:error];
        case ShaderTypeFragment:
            return [self compileSPIRV:source language:EShLangFragment error:error];
    }
}

- (ShaderProgram *)compileSPIRV:(NSString *)src language:(EShLanguage)language error:(NSError **)error
{
    TShader    shader(language);
    const char *str = src.UTF8String;
    shader.setStrings(&str, 1);
    
    EShMessages messages  = static_cast<EShMessages>(EShMsgDefault | EShMsgVulkanRules | EShMsgSpvRules);
    
    const int DEFAULT_VERSION = 110;
    
    string msg;
    auto forbid_include = glslang::TShader::ForbidIncluder();
    if (!shader.preprocess(&glslang::DefaultTBuiltInResource, DEFAULT_VERSION, ENoProfile, false, false, messages, &msg, forbid_include)) {
        if (error != nil)
        {
            // skipped modern syntax here as it was breaking Xcode
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      NSLocalizedString(@"Failed to preprocess shader", @"Shader failed to compile"), NSLocalizedDescriptionKey,
                                      @(msg.c_str()), NSLocalizedFailureReasonErrorKey,
                                      nil];
            *error = [NSError errorWithDomain:OEShaderErrorDomain
                                         code:OEShaderCompilePreprocessError
                                     userInfo:userInfo];
        }
    
        os_log_error(OE_LOG_DEFAULT, "error preprocessing shader: %{public}s", msg.c_str());
        return nil;
    }
    
    if (!shader.parse(&glslang::DefaultTBuiltInResource, DEFAULT_VERSION, false, messages, forbid_include)) {
        if (error != nil)
        {
            // skipped modern syntax here as it was breaking Xcode
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      NSLocalizedString(@"Failed to parse shader", @"Shader failed to compile"), NSLocalizedDescriptionKey,
                                      @(shader.getInfoLog()), NSLocalizedFailureReasonErrorKey,
                                      nil];
            *error = [NSError errorWithDomain:OEShaderErrorDomain
                                         code:OEShaderCompileParseError
                                     userInfo:userInfo];
        }
        
        os_log_error(OE_LOG_DEFAULT, "error parsing shader info log: %{public}s", shader.getInfoLog());
        return nil;
    }
    
    TProgram program;
    program.addShader(&shader);
    
    if (!program.link(messages)) {
        if (error != nil)
        {
            // skipped modern syntax here as it was breaking Xcode
            NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      NSLocalizedString(@"Failed to link shader", @"Shader failed to compile"), NSLocalizedDescriptionKey,
                                      @(program.getInfoLog()), NSLocalizedFailureReasonErrorKey,
                                      nil];
            *error = [NSError errorWithDomain:OEShaderErrorDomain
                                         code:OEShaderCompileLinkError
                                     userInfo:userInfo];
        }
        
        os_log_error(OE_LOG_DEFAULT, "error linking shader info log: %{public}s", program.getInfoLog());
        os_log_error(OE_LOG_DEFAULT, "error linking shader info debug log: %{public}s", program.getInfoDebugLog());
        return nil;
    }
    
    shared_ptr<vector<uint32_t>> spirv(new vector<uint32_t>());
    GlslangToSpv(*program.getIntermediate(language), *spirv.get());
    
    spvtools::Optimizer opt(SPV_ENV_UNIVERSAL_1_5);
    opt.RegisterPass(spvtools::CreateCCPPass())
        .RegisterPass(spvtools::CreateDeadBranchElimPass())
        .RegisterPass(spvtools::CreateAggressiveDCEPass())
        .RegisterPass(spvtools::CreateSSARewritePass())
        .RegisterPass(spvtools::CreateAggressiveDCEPass())
        .RegisterPass(spvtools::CreateEliminateDeadConstantPass())
        .RegisterPass(spvtools::CreateAggressiveDCEPass());

    bool ok = opt.Run(spirv->data(), spirv->size(), spirv.get());
    
    return [[ShaderProgram alloc] initWithVector:spirv];
}

@end

@implementation ShaderProgram
{
    shared_ptr<vector<uint32_t>> _spirv;
}

- (instancetype)initWithVector:(shared_ptr<vector<uint32_t>>)spirv
{
    self = [super init];
    
    _spirv = spirv;
    
    return self;
}

- (SpvId const *)spirv
{
    return _spirv->data();
}

- (size_t)spirvLength
{
    return _spirv->size();
}

- (size_t)spirvLengthBytes
{
    return _spirv->size() * sizeof(SpvId);
}

@end

