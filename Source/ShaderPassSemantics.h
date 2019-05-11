//
// Created by Stuart Carnie on 2019-05-06.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#import <Foundation/Foundation.h>

@import Metal;

typedef NSString *OEShaderTextureSemantic NS_STRING_ENUM;

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

typedef NSString *OEShaderBufferSemantic NS_STRING_ENUM;

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
 * Identifies a float parameter buffer.
 *
 * @details Shaders refer to float parameters by name.
 */
FOUNDATION_EXPORT OEShaderBufferSemantic const OEShaderBufferSemanticFloatParameter;

@interface OEShaderConstants : NSObject
+ (NSArray<OEShaderTextureSemantic> *)textureSemantics;

+ (NSArray<OEShaderBufferSemantic> *)bufferSemantics;
@end

#define kMaxShaderPasses 26
#define kMaxTextures     8
#define kMaxParameters   128
#define kMaxFrameHistory 128

typedef NS_ENUM(NSUInteger, SlangFormat) {
    SlangFormatUnknown = 0,
    SlangFormatR8Unorm,
    SlangFormatR8Uint,
    SlangFormatR8Sint,
    SlangFormatR8G8Unorm,
    SlangFormatR8G8Uint,
    SlangFormatR8G8Sint,
    SlangFormatR8G8B8A8Unorm,
    SlangFormatR8G8B8A8Uint,
    SlangFormatR8G8B8A8Sint,
    SlangFormatR8G8B8A8Srgb,
    SlangFormatA2B10G10R10UnormPack32,
    SlangFormatA2B10G10R10UintPack32,
    SlangFormatR16Uint,
    SlangFormatR16Sint,
    SlangFormatR16Sfloat,
    SlangFormatR16G16Uint,
    SlangFormatR16G16Sint,
    SlangFormatR16G16Sfloat,
    SlangFormatR16G16B16A16Uint,
    SlangFormatR16G16B16A16Sint,
    SlangFormatR16G16B16A16Sfloat,
    SlangFormatR32Uint,
    SlangFormatR32Sint,
    SlangFormatR32Sfloat,
    SlangFormatR32G32Uint,
    SlangFormatR32G32Sint,
    SlangFormatR32G32Sfloat,
    SlangFormatR32G32B32A32Uint,
    SlangFormatR32G32B32A32Sint,
    SlangFormatR32G32B32A32Sfloat,
    SlangFormatMax
};


/*! @brief Converts a GL Slang format string */
extern SlangFormat SlangFormatFromGLSlangNSString(NSString *str);

#pragma mark -

extern NSString *const OEShaderErrorDomain;

typedef NS_ERROR_ENUM(OEShaderErrorDomain, OEShaderErrorCodes) {
    OEShaderMissingVersion = -1,
    OEShaderMultipleFormatPragma = -2,
    OEShaderMultipleNamePragma = -3,
    OEShaderDuplicateParameterPragma = -4,
};

typedef NS_OPTIONS(NSUInteger, StageUsage) {
    StageUsageNone = 0,
    StageUsageVertex = (1 << 0), // semantic is used by the vertex shader
    StageUsageFragment = (1 << 1), // semantic is used by the fragment shader
};

typedef NS_ENUM(NSUInteger, ShaderType) {
    ShaderTypeNone = 0,
    ShaderTypeSlang,
    ShaderTypeMetal,
};

typedef NS_ENUM(NSUInteger, ShaderPassScale) {
    ShaderPassScaleInput = 0,
    ShaderPassScaleAbsolute,
    ShaderPassScaleViewport,
    ShaderPassScaleInvalid,
};

typedef NS_ENUM(NSUInteger, ShaderPassFilter) {
    ShaderPassFilterUnspecified = 0,
    ShaderPassFilterLinear,
    ShaderPassFilterNearest,
    ShaderPassFilterCount,
};

typedef NS_ENUM(NSUInteger, ShaderPassWrap) {
    ShaderPassWrapBorder = 0,
    ShaderPassWrapDefault = ShaderPassWrapBorder,
    ShaderPassWrapEdge,
    ShaderPassWrapRepeat,
    ShaderPassWrapMirroredRepeat,
    ShaderPassWrapCount,
};

@interface ShaderPassUniformBinding : NSObject
@property (nonatomic) void *data;
@property (nonatomic) size_t size;
@property (nonatomic) size_t offset;
@property (nonatomic) NSString *name;
@end

@interface ShaderPassBufferBinding : NSObject
@property (nonatomic) StageUsage stageUsage;
@property (nonatomic) NSUInteger binding;
@property (nonatomic) size_t size;
@property (nonatomic, readonly) NSArray<ShaderPassUniformBinding *> *uniforms;

- (ShaderPassUniformBinding *)addUniformData:(void *)data size:(size_t)size offset:(size_t)offset name:(NSString *)name;
@end

@interface ShaderPassTextureBinding : NSObject
@property (nonatomic) id <MTLTexture> __unsafe_unretained *texture;
@property (nonatomic) ShaderPassWrap wrap;
@property (nonatomic) ShaderPassFilter filter;
@property (nonatomic) StageUsage stageUsage;
@property (nonatomic) NSUInteger binding;
@property (nonatomic) NSString *name;

@end

@interface ShaderPassBindings : NSObject
@property (nonatomic) SlangFormat format;
@property (nonatomic, readonly) NSArray<ShaderPassBufferBinding *> *buffers;
@property (nonatomic, readonly) NSArray<ShaderPassTextureBinding *> *textures;

- (ShaderPassTextureBinding *)addTexture:(id <MTLTexture> __unsafe_unretained *)texture;

@end

@interface ShaderPassBufferSemantics : NSObject
@property (nonatomic) void *data;
@end

@interface ShaderPassTextureSemantics : NSObject
@property (nonatomic) id <MTLTexture> __unsafe_unretained *texture;
@property (nonatomic) size_t textureStride;
@property (nonatomic) void *textureSize;
@property (nonatomic) size_t sizeStride;
@end

@interface ShaderPassSemantics : NSObject

@property (nonatomic, readonly) NSDictionary<OEShaderTextureSemantic, ShaderPassTextureSemantics *> *textures;
@property (nonatomic, readonly) NSDictionary<OEShaderBufferSemantic, ShaderPassBufferSemantics *> *uniforms;

- (void)addTexture:(id <MTLTexture> __unsafe_unretained *)texture
            stride:(size_t)ts
              size:(void *)size
            stride:(size_t)ss
          semantic:(OEShaderTextureSemantic)semantic;

- (void)addUniformData:(void *)data semantic:(OEShaderBufferSemantic)semantic;
@end
