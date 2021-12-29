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

#import <OpenEmuShaders/OEEnums.h>

NS_ASSUME_NONNULL_BEGIN

@class SlangShader;
@class OEPixelBuffer;
@class ShaderCompilerOptions;

typedef void (^OEImageHandler)(NSBitmapImageRep * _Nullable, NSError * _Nullable);

@interface OEFilterChain : NSObject

@property (nonatomic, readonly) CGRect              sourceRect;
@property (nonatomic, readonly) CGSize              sourceAspectSize;
@property (nonatomic)           id<MTLTexture>      sourceTexture;
@property (nonatomic)           BOOL                sourceTextureIsFlipped;
@property (nonatomic, readonly) SlangShader         *shader;
@property (nonatomic)           CGSize              drawableSize;

/*! Indicates the direction frames are progressing
 *
 * @remarks
 * Maps to the @c FrameDirection uniform in shaders.
 */
@property (nonatomic)           NSInteger           frameDirection;


- (instancetype)initWithDevice:(id<MTLDevice>)device;

- (void)setSourceRect:(CGRect)rect aspect:(CGSize)aspect;
- (void)setDrawableSize:(CGSize)drawableSize;

- (OEPixelBuffer *)newBufferWithFormat:(OEMTLPixelFormat)format height:(NSUInteger)height bytesPerRow:(NSUInteger)bytesPerRow;
- (OEPixelBuffer *)newBufferWithFormat:(OEMTLPixelFormat)format height:(NSUInteger)height bytesPerRow:(NSUInteger)bytesPerRow bytes:(void *)pointer;

- (void)renderOffscreenPassesWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer;
- (void)renderFinalPassWithCommandEncoder:(id<MTLRenderCommandEncoder>)commandEncoder;

- (void)renderWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer renderPassDescriptor:(MTLRenderPassDescriptor *)renderPassDescriptor;

/*! @brief Returns an raw image of the last rendered source pixel buffer.
 *
 * @remarks
 * The image dimensions are equal to the source pixel buffer and therefore not aspect corrected.
 */
- (NSBitmapImageRep *)captureSourceImage;

/*! @brief Returns an image of the last source image after all shaders have been applied */
- (NSBitmapImageRep *)captureOutputImage;

/*! @brief Captures an image by applying all shader effects.
 @warning Returns an error if the image capture fails.
 @see OEFilterChainErrorCodeImageCaptureFailed
 */
- (void)captureOutputImageWithCompletion:(OEImageHandler)handler;

/*! @brief The default filtering mode when a shader pass leaves the value unspecified
 *
 * @details
 * When a shader does not specify a filtering mode, the default
 * will be determined by this method.
 *
 * @param linear YES to use linear filtering
 */
- (void)setDefaultFilteringLinear:(BOOL)linear;
- (BOOL)setShaderFromURL:(NSURL *)url options:(ShaderCompilerOptions *)shaderOptions error:(NSError **)error;
- (void)setValue:(CGFloat)value forParameterName:(NSString *)name;
- (void)setValue:(CGFloat)value forParameterIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
