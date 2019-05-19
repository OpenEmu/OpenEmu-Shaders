//
//  OEEnums.m
//  OpenEmuShaders
//
//  Created by Stuart Carnie on 5/14/19.
//  Copyright © 2019 OpenEmu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OEEnums.h"

OEShaderTextureSemantic const OEShaderTextureSemanticOriginal        = @"Original";
OEShaderTextureSemantic const OEShaderTextureSemanticSource          = @"Source";
OEShaderTextureSemantic const OEShaderTextureSemanticOriginalHistory = @"OriginalHistory";
OEShaderTextureSemantic const OEShaderTextureSemanticPassOutput      = @"PassOutput";
OEShaderTextureSemantic const OEShaderTextureSemanticPassFeedback    = @"PassFeedback";
OEShaderTextureSemantic const OEShaderTextureSemanticUser            = @"User";

OEShaderBufferSemantic const OEShaderBufferSemanticMVP               = @"MVP";
OEShaderBufferSemantic const OEShaderBufferSemanticOutput            = @"Output";
OEShaderBufferSemantic const OEShaderBufferSemanticFinalViewportSize = @"FinalViewportSize";
OEShaderBufferSemantic const OEShaderBufferSemanticFrameCount        = @"FrameCount";
OEShaderBufferSemantic const OEShaderBufferSemanticFloatParameter    = @"FloatParameter";

@implementation OEShaderConstants
+ (NSArray<OEShaderTextureSemantic> *)textureSemantics
{
    static dispatch_once_t                  once;
    static NSArray<OEShaderTextureSemantic> *res;
    dispatch_once(&once, ^{
        res = @[
                OEShaderTextureSemanticOriginal,
                OEShaderTextureSemanticSource,
                OEShaderTextureSemanticOriginalHistory,
                OEShaderTextureSemanticPassOutput,
                OEShaderTextureSemanticPassFeedback,
                OEShaderTextureSemanticUser,
        ];
    });
    return res;
}

+ (NSArray<OEShaderBufferSemantic> *)bufferSemantics
{
    static dispatch_once_t                 once;
    static NSArray<OEShaderBufferSemantic> *res;
    dispatch_once(&once, ^{
        res = @[
                OEShaderBufferSemanticMVP,
                OEShaderBufferSemanticOutput,
                OEShaderBufferSemanticFinalViewportSize,
                OEShaderBufferSemanticFrameCount,
                OEShaderBufferSemanticFloatParameter,
        ];
    });
    return res;
}

@end

SlangFormat SlangFormatFromGLSlangNSString(NSString *str)
{
#undef FMT
#define FMT(fmt, x) if ([str isEqualToString:@ #fmt]) return SlangFormat ## x
    FMT(R8_UNORM, R8Unorm);
    FMT(R8_UINT, R8Uint);
    FMT(R8_SINT, R8Sint);
    FMT(R8G8_UNORM, R8G8Unorm);
    FMT(R8G8_UINT, R8G8Uint);
    FMT(R8G8_SINT, R8G8Sint);
    FMT(R8G8B8A8_UNORM, R8G8B8A8Unorm);
    FMT(R8G8B8A8_UINT, R8G8B8A8Uint);
    FMT(R8G8B8A8_SINT, R8G8B8A8Sint);
    FMT(R8G8B8A8_SRGB, R8G8B8A8Srgb);
    FMT(A2B10G10R10_UNORM_PACK32, A2B10G10R10UnormPack32);
    FMT(A2B10G10R10_UINT_PACK32, A2B10G10R10UintPack32);
    FMT(R16_UINT, R16Uint);
    FMT(R16_SINT, R16Sint);
    FMT(R16_SFLOAT, R16Sfloat);
    FMT(R16G16_UINT, R16G16Uint);
    FMT(R16G16_SINT, R16G16Sint);
    FMT(R16G16_SFLOAT, R16G16Sfloat);
    FMT(R16G16B16A16_UINT, R16G16B16A16Uint);
    FMT(R16G16B16A16_SINT, R16G16B16A16Sint);
    FMT(R16G16B16A16_SFLOAT, R16G16B16A16Sfloat);
    FMT(R32_UINT, R32Uint);
    FMT(R32_SINT, R32Sint);
    FMT(R32_SFLOAT, R32Sfloat);
    FMT(R32G32_UINT, R32G32Uint);
    FMT(R32G32_SINT, R32G32Sint);
    FMT(R32G32_SFLOAT, R32G32Sfloat);
    FMT(R32G32B32A32_UINT, R32G32B32A32Uint);
    FMT(R32G32B32A32_SINT, R32G32B32A32Sint);
    FMT(R32G32B32A32_SFLOAT, R32G32B32A32Sfloat);
    
    return SlangFormatUnknown;
}
