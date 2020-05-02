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

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

typedef NSString *OEShaderTextureSemantic NS_TYPED_ENUM;

/*!
 * Identifies the input texture to the filter chain.
 *
 * @details Shaders refer to the input texture via the
 * @c Original and @c OriginalSize symbols.
 * */
FOUNDATION_EXPORT OEShaderTextureSemantic const OEShaderTextureSemanticOriginal;

/*!
 * Identifies the output texture from the previous pass.
 *
 * @details Shaders can refer to the previous source texture via
 * the @c Source and @c SourceSize symbols.
 *
 * @remark If the filter chain is executing the first pass, this is the same as
 * @c Original.
 */
FOUNDATION_EXPORT OEShaderTextureSemantic const OEShaderTextureSemanticSource;

/*!
 * Identifies the historical input textures.
 *
 * @details Shaders can refer to the history textures via the
 * @c OriginalHistoryN and @c OriginalSizeN symbols, where N
 * specifies the number of @c Original frames back to read.
 *
 * @example To read 2 frames prior, use @c OriginalHistory2 and @c OriginalSize2
 */
FOUNDATION_EXPORT OEShaderTextureSemantic const OEShaderTextureSemanticOriginalHistory;

/*!
 * Identifies the pass output textures.
 *
 * @details Shaders can refer to the output of prior passes via the
 * @c PassOutputN and @c PassOutputSizeN symbols, where N specifies the
 * pass number.
 *
 * @example In pass 5, sampling the output of pass 2
 * would use @c PassOutput2 and @c PassOutputSize2
 */
FOUNDATION_EXPORT OEShaderTextureSemantic const OEShaderTextureSemanticPassOutput;

/*!
 * Identifies the pass feedback textures.
 *
 * @details Shaders can refer to the output of the previous
 * frame of pass N via the @c PassFeedbackN and @c PassFeedbackSizeN
 * symbols, where N specifies the pass number.
 *
 * @example To sample the output of pass 2 from the prior frame,
 * use @c PassFeedback2 and @c PassFeedbackSize2
 */
FOUNDATION_EXPORT OEShaderTextureSemantic const OEShaderTextureSemanticPassFeedback;

/*!
 * Identifies the lookup or user textures.
 *
 * @details Shaders refer to user lookup or user textures by name as defined
 * in the plist file.
 *
 */
FOUNDATION_EXPORT OEShaderTextureSemantic const OEShaderTextureSemanticUser;

typedef NSString *OEShaderBufferSemantic NS_TYPED_ENUM;

/*!
 * Identifies the 4x4 float model-view-projection matrix buffer.
 *
 * @details Shaders refer to the matrix constant via the @c MVP symbol.
 */
FOUNDATION_EXPORT OEShaderBufferSemantic const OEShaderBufferSemanticMVP;

/*!
 * Identifies the vec4 float containing the viewport size of the current pass.
 *
 * @details Shaders refer to the viewport size constant via the @c OutputSize symbol.
 *
 * @remarks
 * The @c x and @c y fields refer to the size of the output in pixels
 * The @c z and @c w fields refer to the inverse; 1/x and 1/y
 */
FOUNDATION_EXPORT OEShaderBufferSemantic const OEShaderBufferSemanticOutput;

/*!
 * Identifies the vec4 float containing the final viewport output size.
 *
 * @details Shaders refer to the final output size constant via the @c FinalViewportSize symbol.
 *
 * @remarks
 * The @c x and @c y fields refer to the size of the output in pixels
 * The @c z and @c w fields refer to the inverse; 1/x and 1/y
 */
FOUNDATION_EXPORT OEShaderBufferSemantic const OEShaderBufferSemanticFinalViewportSize;

/*!
 * Identifies the uint containing the frame count.
 *
 * @details Shaders refer to the frame count constant via the @c FrameCount symbol.
 *
 * @remarks
 * This value increments by one each frame.
 */
FOUNDATION_EXPORT OEShaderBufferSemantic const OEShaderBufferSemanticFrameCount;

/*!
 * Identifies the int containing the frame direction; 1 is forward, -1 is backwards.
 *
 * @details Shaders refer to the frame direction constant via the @c FrameDirection symbol.
 */
FOUNDATION_EXPORT OEShaderBufferSemantic const OEShaderBufferSemanticFrameDirection;

/*!
 * Identifies a float parameter buffer.
 *
 * @details Shaders refer to float parameters by name.
 */
FOUNDATION_EXPORT OEShaderBufferSemantic const OEShaderBufferSemanticFloatParameter;

@interface OEShaderConstants : NSObject
+ (NSArray<OEShaderTextureSemantic> *)textureSemantics;
+ (NSArray<OEShaderBufferSemantic> *)bufferSemantics;
@end

#define kMaxShaderPasses    26
#define kMaxTextures        8
#define kMaxParameters      256
#define kMaxFrameHistory    128
#define kMaxConstantBuffers 2
#define kMaxShaderBindings  16

/*! @brief Converts a GL Slang format string to Metal */
extern MTLPixelFormat MTLPixelFormatFromGLSlangNSString(NSString *str);

#pragma mark -

typedef NS_ENUM(NSUInteger, OEMTLPixelFormat)
{
    OEMTLPixelFormatInvalid,
    
    // 16-bit formats
    OEMTLPixelFormatBGRA4Unorm NS_SWIFT_NAME(bgra4Unorm),
    OEMTLPixelFormatB5G6R5Unorm NS_SWIFT_NAME(b5g6r5Unorm),
    OEMTLPixelFormatR5G5B5A1Unorm NS_SWIFT_NAME(r5g5b5a1Unorm),
    
    // 32-bit formats, 8 bits per pixel
    OEMTLPixelFormatRGBA8Unorm NS_SWIFT_NAME(rgba8Unorm),
    OEMTLPixelFormatABGR8Unorm NS_SWIFT_NAME(abgr8Unorm),

    // native, no conversion
    OEMTLPixelFormatBGRA8Unorm NS_SWIFT_NAME(bgra8Unorm),
    OEMTLPixelFormatBGRX8Unorm NS_SWIFT_NAME(rgbx8Unorm), // no alpha
    
    OEMTLPixelFormatCount,
};

extern NSUInteger   OEMTLPixelFormatToBPP(OEMTLPixelFormat format);
extern NSString     *NSStringFromOEMTLPixelFormat(OEMTLPixelFormat format);
extern BOOL         OEMTLPixelFormatIsNative(OEMTLPixelFormat format);


typedef NS_OPTIONS(NSUInteger, OEStageUsage)
{
    OEStageUsageNone     = 0,
    OEStageUsageVertex   = (1 << 0), // semantic is used by the vertex shader
    OEStageUsageFragment = (1 << 1), // semantic is used by the fragment shader
};

typedef NS_ENUM(NSUInteger, OEShaderPassScale)
{
    OEShaderPassScaleInvalid = 0,
    OEShaderPassScaleSource,
    OEShaderPassScaleAbsolute,
    OEShaderPassScaleViewport,
};

typedef NS_ENUM(NSUInteger, OEShaderPassFilter)
{
    OEShaderPassFilterUnspecified = 0,
    OEShaderPassFilterLinear,
    OEShaderPassFilterNearest,
    OEShaderPassFilterCount,
};

typedef NS_ENUM(NSUInteger, OEShaderPassWrap)
{
    OEShaderPassWrapBorder  = 0,
    OEShaderPassWrapDefault = OEShaderPassWrapBorder,
    OEShaderPassWrapEdge,
    OEShaderPassWrapRepeat,
    OEShaderPassWrapMirroredRepeat,
    OEShaderPassWrapCount,
};

#pragma mark - Errors

extern NSErrorDomain const OEShaderErrorDomain;

NS_ERROR_ENUM(OEShaderErrorDomain) {
    OEShaderCompilePreprocessError  = -1,
    OEShaderCompileParseError       = -2,
    OEShaderCompileLinkError        = -3,
};

