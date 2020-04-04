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
#include "SPIRV/GlslangToSpv.h"
#include "logging.h"
#include "spirv-tools/libspirv.hpp"
#include "spirv-tools/optimizer.hpp"


using namespace glslang;
using namespace std;

@interface ShaderProgram()
- (instancetype)initWithVector:(shared_ptr<vector<uint32_t>>)spirv;
@end

@implementation SlangCompiler

static TBuiltInResource resources;

+ (void)initialize
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        InitializeProcess();
        
        resources.maxLights                                   = 32;
        resources.maxClipPlanes                               = 6;
        resources.maxTextureUnits                             = 32;
        resources.maxTextureCoords                            = 32;
        resources.maxVertexAttribs                            = 64;
        resources.maxVertexUniformComponents                  = 4096;
        resources.maxVaryingFloats                            = 64;
        resources.maxVertexTextureImageUnits                  = 32;
        resources.maxCombinedTextureImageUnits                = 80;
        resources.maxTextureImageUnits                        = 32;
        resources.maxFragmentUniformComponents                = 4096;
        resources.maxDrawBuffers                              = 32;
        resources.maxVertexUniformVectors                     = 128;
        resources.maxVaryingVectors                           = 8;
        resources.maxFragmentUniformVectors                   = 16;
        resources.maxVertexOutputVectors                      = 16;
        resources.maxFragmentInputVectors                     = 15;
        resources.minProgramTexelOffset -= 8;
        resources.maxProgramTexelOffset                       = 7;
        resources.maxClipDistances                            = 8;
        resources.maxComputeWorkGroupCountX                   = 65535;
        resources.maxComputeWorkGroupCountY                   = 65535;
        resources.maxComputeWorkGroupCountZ                   = 65535;
        resources.maxComputeWorkGroupSizeX                    = 1024;
        resources.maxComputeWorkGroupSizeY                    = 1024;
        resources.maxComputeWorkGroupSizeZ                    = 64;
        resources.maxComputeUniformComponents                 = 1024;
        resources.maxComputeTextureImageUnits                 = 16;
        resources.maxComputeImageUniforms                     = 8;
        resources.maxComputeAtomicCounters                    = 8;
        resources.maxComputeAtomicCounterBuffers              = 1;
        resources.maxVaryingComponents                        = 60;
        resources.maxVertexOutputComponents                   = 64;
        resources.maxGeometryInputComponents                  = 64;
        resources.maxGeometryOutputComponents                 = 128;
        resources.maxFragmentInputComponents                  = 128;
        resources.maxImageUnits                               = 8;
        resources.maxCombinedImageUnitsAndFragmentOutputs     = 8;
        resources.maxCombinedShaderOutputResources            = 8;
        resources.maxImageSamples                             = 0;
        resources.maxVertexImageUniforms                      = 0;
        resources.maxTessControlImageUniforms                 = 0;
        resources.maxTessEvaluationImageUniforms              = 0;
        resources.maxGeometryImageUniforms                    = 0;
        resources.maxFragmentImageUniforms                    = 8;
        resources.maxCombinedImageUniforms                    = 8;
        resources.maxGeometryTextureImageUnits                = 16;
        resources.maxGeometryOutputVertices                   = 256;
        resources.maxGeometryTotalOutputComponents            = 1024;
        resources.maxGeometryUniformComponents                = 1024;
        resources.maxGeometryVaryingComponents                = 64;
        resources.maxTessControlInputComponents               = 128;
        resources.maxTessControlOutputComponents              = 128;
        resources.maxTessControlTextureImageUnits             = 16;
        resources.maxTessControlUniformComponents             = 1024;
        resources.maxTessControlTotalOutputComponents         = 4096;
        resources.maxTessEvaluationInputComponents            = 128;
        resources.maxTessEvaluationOutputComponents           = 128;
        resources.maxTessEvaluationTextureImageUnits          = 16;
        resources.maxTessEvaluationUniformComponents          = 1024;
        resources.maxTessPatchComponents                      = 120;
        resources.maxPatchVertices                            = 32;
        resources.maxTessGenLevel                             = 64;
        resources.maxViewports                                = 16;
        resources.maxVertexAtomicCounters                     = 0;
        resources.maxTessControlAtomicCounters                = 0;
        resources.maxTessEvaluationAtomicCounters             = 0;
        resources.maxGeometryAtomicCounters                   = 0;
        resources.maxFragmentAtomicCounters                   = 8;
        resources.maxCombinedAtomicCounters                   = 8;
        resources.maxAtomicCounterBindings                    = 1;
        resources.maxVertexAtomicCounterBuffers               = 0;
        resources.maxTessControlAtomicCounterBuffers          = 0;
        resources.maxTessEvaluationAtomicCounterBuffers       = 0;
        resources.maxGeometryAtomicCounterBuffers             = 0;
        resources.maxFragmentAtomicCounterBuffers             = 1;
        resources.maxCombinedAtomicCounterBuffers             = 1;
        resources.maxAtomicCounterBufferSize                  = 16384;
        resources.maxTransformFeedbackBuffers                 = 4;
        resources.maxTransformFeedbackInterleavedComponents   = 64;
        resources.maxCullDistances                            = 8;
        resources.maxCombinedClipAndCullDistances             = 8;
        resources.maxSamples                                  = 4;
        resources.limits.nonInductiveForLoops                 = 1;
        resources.limits.whileLoops                           = 1;
        resources.limits.doWhileLoops                         = 1;
        resources.limits.generalUniformIndexing               = 1;
        resources.limits.generalAttributeMatrixVectorIndexing = 1;
        resources.limits.generalVaryingIndexing               = 1;
        resources.limits.generalSamplerIndexing               = 1;
        resources.limits.generalVariableIndexing              = 1;
        resources.limits.generalConstantMatrixVectorIndexing  = 1;
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
    if (!shader.preprocess(&resources, DEFAULT_VERSION, ENoProfile, false, false, messages, &msg, forbid_include)) {
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
    
    if (!shader.parse(&resources, DEFAULT_VERSION, false, messages, forbid_include)) {
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
    opt.RegisterPerformancePasses();
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

