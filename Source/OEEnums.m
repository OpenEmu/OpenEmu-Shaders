//
//  OEEnums.m
//  OpenEmuShaders
//
//  Created by Stuart Carnie on 5/14/19.
//  Copyright © 2019 OpenEmu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OEEnums.h"
#import "OELogging.h"

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
OEShaderBufferSemantic const OEShaderBufferSemanticFrameDirection    = @"FrameDirection";
OEShaderBufferSemantic const OEShaderBufferSemanticFloatParameter    = @"FloatParameter";

NSErrorDomain const OEShaderErrorDomain = @"org.openemu.shaders.ErrorDomain";

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
                OEShaderBufferSemanticFrameDirection,
                OEShaderBufferSemanticFloatParameter,
        ];
    });
    return res;
}

@end

MTLPixelFormat MTLPixelFormatFromGLSlangNSString(NSString *str)
{
#undef FMT
#define FMT(fmt, x) if ([str isEqualToString:@ #fmt]) return MTLPixelFormat ## x
    FMT(R8_UNORM, R8Unorm);
    FMT(R8_UINT, R8Uint);
    FMT(R8_SINT, R8Sint);
    FMT(R8G8_UNORM, RG8Unorm);
    FMT(R8G8_UINT, RG8Uint);
    FMT(R8G8_SINT, RG8Sint);
    FMT(R8G8B8A8_UNORM, RGBA8Unorm);
    FMT(R8G8B8A8_UINT, RGBA8Uint);
    FMT(R8G8B8A8_SINT, RGBA8Sint);
    FMT(R8G8B8A8_SRGB, RGBA8Unorm_sRGB);
    FMT(A2B10G10R10_UNORM_PACK32, RGB10A2Unorm);
    FMT(A2B10G10R10_UINT_PACK32, RGB10A2Uint);
    FMT(R16_UINT, R16Uint);
    FMT(R16_SINT, R16Sint);
    FMT(R16_SFLOAT, R16Float);
    FMT(R16G16_UINT, RG16Uint);
    FMT(R16G16_SINT, RG16Sint);
    FMT(R16G16_SFLOAT, RG16Float);
    FMT(R16G16B16A16_UINT, RGBA16Uint);
    FMT(R16G16B16A16_SINT, RGBA16Sint);
    FMT(R16G16B16A16_SFLOAT, RGBA16Float);
    FMT(R32_UINT, R32Uint);
    FMT(R32_SINT, R32Sint);
    FMT(R32_SFLOAT, R32Float);
    FMT(R32G32_UINT, RG32Uint);
    FMT(R32G32_SINT, RG32Sint);
    FMT(R32G32_SFLOAT, RG32Float);
    FMT(R32G32B32A32_UINT, RGBA32Uint);
    FMT(R32G32B32A32_SINT, RGBA32Sint);
    FMT(R32G32B32A32_SFLOAT, RGBA32Float);
    
    return MTLPixelFormatInvalid;
}

NSUInteger OEMTLPixelFormatToBPP(OEMTLPixelFormat format)
{
    switch (format)
    {
        case OEMTLPixelFormatABGR8Unorm:
        case OEMTLPixelFormatRGBA8Unorm:
        case OEMTLPixelFormatBGRA8Unorm:
        case OEMTLPixelFormatBGRX8Unorm:
            return 4;
        
        case OEMTLPixelFormatB5G6R5Unorm:
        case OEMTLPixelFormatR5G5B5A1Unorm:
        case OEMTLPixelFormatBGRA4Unorm:
            return 2;
        
        default:
            os_log_error(OE_LOG_DEFAULT, "RPixelFormatToBPP: unknown RPixel format: %lu", format);
            return 4;
    }
}

static NSString *OEMTLPixelStrings[OEMTLPixelFormatCount];

NSString *NSStringFromOEMTLPixelFormat(OEMTLPixelFormat format)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

#define STRING(literal) OEMTLPixelStrings[literal] = @#literal
        STRING(OEMTLPixelFormatInvalid);
        STRING(OEMTLPixelFormatB5G6R5Unorm);
        STRING(OEMTLPixelFormatR5G5B5A1Unorm);
        STRING(OEMTLPixelFormatBGRA4Unorm);
        STRING(OEMTLPixelFormatABGR8Unorm);
        STRING(OEMTLPixelFormatRGBA8Unorm);
        STRING(OEMTLPixelFormatBGRA8Unorm);
        STRING(OEMTLPixelFormatBGRX8Unorm);
#undef STRING
    
    });
    
    if (format >= OEMTLPixelFormatCount)
    {
        format = OEMTLPixelFormatInvalid;
    }
    
    return OEMTLPixelStrings[format];
}

BOOL OEMTLPixelFormatIsNative(OEMTLPixelFormat format)
{
    switch (format) {
        case OEMTLPixelFormatABGR8Unorm:
        case OEMTLPixelFormatRGBA8Unorm:
        case OEMTLPixelFormatR5G5B5A1Unorm:
        case OEMTLPixelFormatB5G6R5Unorm:
        case OEMTLPixelFormatBGRA4Unorm:
            return NO;
            
        case OEMTLPixelFormatBGRA8Unorm:
        case OEMTLPixelFormatBGRX8Unorm:
            return YES;
            
        default:
            break;
    }
    
    NSCAssert1(false, @"unsupported format: %lu", format);
    return NO;
}
