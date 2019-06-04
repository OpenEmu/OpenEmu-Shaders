/**
 * Copyright (c) 2019 Stuart Carnie
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

#import "OEMTLPixelConverter.h"
#import "ShaderTypes.h"

@interface Filter : NSObject

@property (nonatomic, readonly) id<MTLSamplerState> sampler;

- (instancetype)initWithKernel:(id<MTLComputePipelineState>)kernel bytesPerPixel:(NSUInteger)bytesPerPixel;

- (void)convertFromTexture:(id<MTLTexture>)src
                 toTexture:(id<MTLTexture>)dst commandBuffer:(id<MTLCommandBuffer>)cb;
- (void)convertFromBuffer:(id<MTLBuffer>)src sourceOrigin:(MTLOrigin)sourceOrigin sourceBytesPerRow:(NSUInteger)bytesPerRow
                toTexture:(id<MTLTexture>)dst commandBuffer:(id<MTLCommandBuffer>)cb;

+ (instancetype)newFilterWithFunctionName:(NSString *)name
                                   device:(id<MTLDevice>)device
                                  library:(id<MTLLibrary>)library
                                   format:(OEMTLPixelFormat)format
                                    error:(NSError **)error;

@end

@implementation OEMTLPixelConverter
{
    Filter *_texToTex[OEMTLPixelFormatCount]; // convert to bgra8888
    Filter *_bufToTex[OEMTLPixelFormatCount]; // convert to bgra8888
}

typedef NS_ENUM(NSUInteger, ConverterType)
{
    ConverterTypeTexToTex = 0,
    ConverterTypeBufToTex = 1
};

typedef struct {
    ConverterType       type;
    OEMTLPixelFormat    format;
    char const *        name;
} ConverterInfo;

static ConverterInfo const converterInfos[] = {
    {ConverterTypeTexToTex, OEMTLPixelFormatBGRA4Unorm,    "convert_bgra4444_to_bgra8888"},
    {ConverterTypeTexToTex, OEMTLPixelFormatB5G6R5Unorm,   "convert_rgb565_to_bgra8888"},
    {ConverterTypeBufToTex, OEMTLPixelFormatBGRA4Unorm,    "convert_bgra4444_to_bgra8888_buf"},
    {ConverterTypeBufToTex, OEMTLPixelFormatB5G6R5Unorm,   "convert_rgb565_to_bgra8888_buf"},
    {ConverterTypeBufToTex, OEMTLPixelFormatR5G5B5A1Unorm, "convert_bgra5551_to_bgra8888_buf"},
    {ConverterTypeBufToTex, OEMTLPixelFormatRGBA8Unorm,    "convert_rgba8888_to_bgra8888_buf"},
};

- (instancetype)initWithDevice:(id<MTLDevice>)device library:(id<MTLLibrary>)library error:(NSError **)error
{
    self = [super init];
    
    NSError *err = nil;
    for (int i = 0; i < sizeof(converterInfos)/sizeof(*converterInfos); i++) {
        ConverterInfo const * ci = &converterInfos[i];
        Filter *fi = [Filter newFilterWithFunctionName:[NSString stringWithUTF8String:ci->name]
                                                device:device
                                               library:library
                                                format:ci->format
                                                 error:&err];
        if (err) {
            if (error) {
                *error = err;
            }
            NSLog(@"unable to create '%s' conversion filter: %@", ci->name, err.localizedDescription);
            return nil;
        }
        
        if (ci->type == ConverterTypeTexToTex) {
            _texToTex[ci->format]  = fi;
        } else {
            _bufToTex[ci->format]  = fi;
        }
    }
    
    return self;
}

- (void)convertFromTexture:(id<MTLTexture>)src sourceFormat:(OEMTLPixelFormat)fmt
                 toTexture:(id<MTLTexture>)dst commandBuffer:(id<MTLCommandBuffer>)cb
{
    Filter *filter = _texToTex[fmt];
    assert(filter != nil);
    [filter convertFromTexture:src toTexture:dst commandBuffer:cb];
}

- (void)convertFromBuffer:(id<MTLBuffer>)src sourceFormat:(OEMTLPixelFormat)fmt sourceOrigin:(MTLOrigin)sourceOrigin sourceBytesPerRow:(NSUInteger)bytesPerRow
                toTexture:(id<MTLTexture>)dst commandBuffer:(id<MTLCommandBuffer>)cb
{
    Filter *filter = _bufToTex[fmt];
    assert(filter != nil);
    [filter convertFromBuffer:src sourceOrigin:sourceOrigin sourceBytesPerRow:bytesPerRow toTexture:dst commandBuffer:cb];
}

@end

@implementation Filter
{
    id<MTLComputePipelineState> _kernel;
    NSUInteger                  _bytesPerPixel;
}

+ (instancetype)newFilterWithFunctionName:(NSString *)name
                                   device:(id<MTLDevice>)device
                                  library:(id<MTLLibrary>)library
                                   format:(OEMTLPixelFormat)format
                                    error:(NSError **)error
{
    id<MTLFunction>             function = [library newFunctionWithName:name];
    id<MTLComputePipelineState> kernel   = [device newComputePipelineStateWithFunction:function error:error];
    if (*error != nil) {
        return nil;
    }
    
    return [[Filter alloc] initWithKernel:kernel bytesPerPixel:OEMTLPixelFormatToBPP(format)];
}

- (instancetype)initWithKernel:(id<MTLComputePipelineState>)kernel bytesPerPixel:(NSUInteger)bytesPerPixel
{
    if (self = [super init]) {
        _kernel         = kernel;
        _bytesPerPixel  = bytesPerPixel;
    }
    return self;
}

- (void)convertFromTexture:(id<MTLTexture>)src
                 toTexture:(id<MTLTexture>)dst commandBuffer:(id<MTLCommandBuffer>)cb
{
    id<MTLComputeCommandEncoder> ce = [cb computeCommandEncoder];
    ce.label = @"filter cb";
    
    [ce setComputePipelineState:_kernel];
    id<MTLTexture> textures[2] = { src, dst };
    [ce setTextures:textures withRange:NSMakeRange(0, 2)];
    
    MTLSize size  = MTLSizeMake(16, 16, 1);
    MTLSize count = MTLSizeMake((src.width + size.width + 1) / size.width, (src.height + size.height + 1) / size.height, 1);
    
    [ce dispatchThreadgroups:count threadsPerThreadgroup:size];
    
    [ce endEncoding];
}

- (void)convertFromBuffer:(id<MTLBuffer>)src sourceOrigin:(MTLOrigin)sourceOrigin sourceBytesPerRow:(NSUInteger)bytesPerRow
                toTexture:(id<MTLTexture>)dst commandBuffer:(id<MTLCommandBuffer>)cb
{
    id<MTLComputeCommandEncoder> ce = [cb computeCommandEncoder];
    ce.label = @"filter cb";
    
    [ce setComputePipelineState:_kernel];
    
    BufferUniforms const uni = {
        .origin = simd_make_uint2((uint32_t)sourceOrigin.x, (uint32_t)sourceOrigin.y),
        .stride = (uint32_t)(bytesPerRow / _bytesPerPixel),
    };
    
    [ce setBuffer:src offset:0 atIndex:0];
    [ce setBytes:&uni length:sizeof(uni) atIndex:1];
    [ce setTexture:dst atIndex:0];
    
    MTLSize size  = MTLSizeMake(16, 16, 1);
    MTLSize count = MTLSizeMake((dst.width + size.width + 1) / size.width, (dst.height + size.height + 1) / size.height, 1);
    
    [ce dispatchThreadgroups:count threadsPerThreadgroup:size];
    
    [ce endEncoding];
}

@end
