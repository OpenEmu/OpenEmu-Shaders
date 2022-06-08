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

#import <OpenEmuShaders/OpenEmuShaders-Swift.h>

@interface OENativePixelBuffer: OEPixelBuffer
@end

@interface OEIntermediatePixelBuffer: OEPixelBuffer
- (instancetype)initWithDevice:(id<MTLDevice>)device converter:(MTLBufferFormatConverter *)converter format:(OEMTLPixelFormat)format
                        height:(NSUInteger)height bytesPerRow:(NSUInteger)bytesPerRow
                         bytes:(void * _Nullable)pointer;
@end

@implementation OEPixelBuffer {
@public
    id<MTLDevice>       _device;
    OEMTLPixelFormat    _format;
    NSUInteger          _bpp; // bytes per pixel
    
    id<MTLBuffer>       _intermediate;
    NSUInteger          _sourceBytesPerRow;
    id<MTLBuffer>       _sourceBuffer;
    CGSize              _sourceSize;
    CGRect              _outputRect;
    void               *_contents;
    
    // for unaligned buffers
    void               *_buffer;
    size_t              _bufferLenBytes;
    BOOL                _bufferFree;
    BOOL                _shortCopy;
}

#pragma mark - initializers

- (instancetype)initWithDevice:(id<MTLDevice>)device format:(OEMTLPixelFormat)format
                        height:(NSUInteger)height bytesPerRow:(NSUInteger)bytesPerRow
                         bytes:(void * _Nullable)pointer
{
    if (!(self = [super init])) {
        return nil;
    }
    NSUInteger length = height * bytesPerRow;

    _device             = device;
    _format             = format;
    _bpp                = OEMTLPixelFormatToBPP(format);
    _sourceBytesPerRow  = bytesPerRow;
    _sourceSize         = CGSizeMake(bytesPerRow / _bpp, height);
    _bufferLenBytes     = length;
    _sourceBuffer       = [_device newBufferWithLength:length options:MTLResourceStorageModeShared];

    if (pointer)
    {
        _buffer     = pointer;
        _bufferFree = NO;
    }
    else
    {
        _buffer     = malloc(length);
        _bufferFree = YES;
    }
    
    _contents = _buffer;
    
    return self;
}

- (void)dealloc
{
    if (_bufferFree)
    {
        free(_buffer);
        _buffer = nil;
    }
}

#pragma mark - static initializers

+ (instancetype)bufferWithDevice:(id<MTLDevice>)device converter:(MTLPixelConverter *)converter
                          format:(OEMTLPixelFormat)format height:(NSUInteger)height bytesPerRow:(NSUInteger)bytesPerRow
{
    return [self bufferWithDevice:device converter:converter
                           format:format height:height bytesPerRow:bytesPerRow
                            bytes:nil];
}

+ (instancetype)bufferWithDevice:(id<MTLDevice>)device converter:(MTLPixelConverter *)converter format:(OEMTLPixelFormat)format
                          height:(NSUInteger)height bytesPerRow:(NSUInteger)bytesPerRow
                           bytes:(void * _Nullable)pointer
{
    if (OEMTLPixelFormatIsNative(format))
    {
        return [[OENativePixelBuffer alloc] initWithDevice:device format:format
                                                    height:height bytesPerRow:bytesPerRow
                                                     bytes:pointer];
    }
    
    MTLBufferFormatConverter *conv = [converter bufferConverterWithFormat:format];
    
    return [[OEIntermediatePixelBuffer alloc] initWithDevice:device converter:conv format:format
                                                      height:height bytesPerRow:bytesPerRow
                                                       bytes:pointer];
}

- (void)setOutputRect:(CGRect)outputRect
{
    if (CGRectEqualToRect(_outputRect, outputRect))
    {
        return;
    }
    
    _outputRect    = outputRect;
    // short copy if the buffer > 1MB and were copying < 50% of the buffer.
    _shortCopy     = _bufferLenBytes > 1e6 && _outputRect.size.width * _bpp * _outputRect.size.height <= _bufferLenBytes / 2;
}

- (void)_copyBuffer
{
    if (_shortCopy)
    {
        void     *src = _buffer;
        void     *dst = _sourceBuffer.contents;
        size_t rowLen = _outputRect.size.width*_bpp;

        if (!CGPointEqualToPoint(_outputRect.origin, CGPointZero))
        {
            size_t offset = (size_t)((_outputRect.origin.y * _sourceBytesPerRow) + (_outputRect.origin.x * _bpp));
            src += offset;
            dst += offset;
        }

        for (int y = 0; y < _outputRect.size.height; y++)
        {
            memcpy(dst, src, rowLen);
            src += _sourceBytesPerRow;
            dst += _sourceBytesPerRow;
        }
    }
    else
    {
        memcpy(_sourceBuffer.contents, _buffer, _bufferLenBytes);
    }
}

#pragma mark - internal APIs

- (void)prepareWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer texture:(id<MTLTexture>)texture
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"%s not implemented", sel_getName(_cmd)]
                                 userInfo:nil];
}

@end

@implementation OENativePixelBuffer

- (void)prepareWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer texture:(id<MTLTexture>)texture
{
    if (texture.storageMode != MTLStorageModePrivate) {
        [texture replaceRegion:MTLRegionMake2D(_outputRect.origin.x, _outputRect.origin.y, _outputRect.size.width, _outputRect.size.height)
                   mipmapLevel:0
                     withBytes:_buffer
                   bytesPerRow:_sourceBytesPerRow];
        return;
    }

    [self _copyBuffer];
    
    MTLSize                   size = {.width = (NSUInteger)_outputRect.size.width, .height = (NSUInteger)_outputRect.size.height, .depth = 1};
    MTLOrigin                 zero = {0};
    id<MTLBlitCommandEncoder> bce  = [commandBuffer blitCommandEncoder];

    NSUInteger offset = (_outputRect.origin.y * _sourceBytesPerRow) + _outputRect.origin.x * 4 /* 4 bpp */;
    NSUInteger len    = _sourceBuffer.length - (_outputRect.origin.y * _sourceBytesPerRow);
    [bce copyFromBuffer:_sourceBuffer sourceOffset:offset sourceBytesPerRow:_sourceBytesPerRow sourceBytesPerImage:len sourceSize:size toTexture:texture destinationSlice:0 destinationLevel:0 destinationOrigin:zero];
    [bce endEncoding];
}

@end

@implementation OEIntermediatePixelBuffer {
    MTLBufferFormatConverter *_converter;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device converter:(MTLBufferFormatConverter *)converter format:(OEMTLPixelFormat)format
                        height:(NSUInteger)height bytesPerRow:(NSUInteger)bytesPerRow
                         bytes:(void * _Nullable)pointer
{
    self = [super initWithDevice:device format:format height:height bytesPerRow:bytesPerRow bytes:pointer];
    if (self == nil) {
        return nil;
    }
    
    _converter = converter;
    
    return self;
}

- (void)prepareWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer texture:(id<MTLTexture>)texture
{
    [self _copyBuffer];
    
    MTLOrigin orig = {.x = _outputRect.origin.x, .y = _outputRect.origin.y};
    [_converter convertFromBuffer:_sourceBuffer sourceOrigin:orig sourceBytesPerRow:_sourceBytesPerRow
                        toTexture:texture commandBuffer:commandBuffer];
}

@end
