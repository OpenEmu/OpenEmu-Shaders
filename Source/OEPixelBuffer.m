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

#import "OEPixelBuffer+Internal.h"
#import <OpenEmuShaders/OpenEmuShaders-Swift.h>

typedef NS_OPTIONS(NSUInteger, BufferOption)
{
    BufferOptionNone        = 0,
    BufferOptionCopy        = (1 << 0),
    BufferOptionNoCopy      = (1 << 1), // buffer memory
};

BOOL BufferOptionMustCopy(BufferOption o) {
    return (o & BufferOptionCopy) == BufferOptionCopy;
}

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
    
    id<MTLBuffer>       _intermediate;
    NSUInteger          _sourceBytesPerRow;
    id<MTLBuffer>       _sourceBuffer;
    CGSize              _sourceSize;
    CGRect              _outputRect;
    BufferOption        _options;
    void               *_contents;
    
    // for unaligned buffers
    void               *_buffer;
    size_t              _bufferLenBytes;
}

#pragma mark - initializers

- (instancetype)initWithDevice:(id<MTLDevice>)device format:(OEMTLPixelFormat)format
                        height:(NSUInteger)height bytesPerRow:(NSUInteger)bytesPerRow
                         bytes:(void * _Nullable)pointer
{
    if (!(self = [super init])) {
        return nil;
    }
    
    _device             = device;
    _format             = format;
    _sourceBytesPerRow  = bytesPerRow;
    _sourceSize         = CGSizeMake(bytesPerRow / OEMTLPixelFormatToBPP(format), height);
    _options            = BufferOptionNoCopy;

    NSUInteger length = height * bytesPerRow;
    if (pointer) {
        if (((uintptr_t)pointer % 4096 == 0) && (length % 4096 == 0)) {
            _sourceBuffer = [_device newBufferWithBytesNoCopy:pointer length:length options:MTLResourceStorageModeShared deallocator:nil];
        } else {
            _options        = BufferOptionCopy;
            _buffer         = pointer;
            _bufferLenBytes = length;
            _sourceBuffer   = [_device newBufferWithLength:length options:MTLResourceStorageModeShared];
        }
    } else {
        _sourceBuffer = [_device newBufferWithLength:length options:MTLResourceStorageModeShared];
    }
    
    //_intermediate = [_device newBufferWithLength:length options:MTLResourceStorageModeShared];
    
    _contents = _buffer ?: _sourceBuffer.contents;
    
    return self;
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
    if (BufferOptionMustCopy(_options)) {
        if (texture.storageMode != MTLStorageModePrivate) {
            [texture replaceRegion:MTLRegionMake2D(_outputRect.origin.x, _outputRect.origin.y, _outputRect.size.width, _outputRect.size.height)
                       mipmapLevel:0
                         withBytes:_buffer
                       bytesPerRow:_sourceBytesPerRow];
            return;
        }
        // replaceRegion not supported for private storage mode; fallback to blit
        memcpy(_sourceBuffer.contents, _buffer, _bufferLenBytes);
    }
    
    MTLSize                   size = {.width = (NSUInteger)_outputRect.size.width, .height = (NSUInteger)_outputRect.size.height, .depth = 1};
    MTLOrigin                 zero = {0};
    id<MTLBlitCommandEncoder> bce  = [commandBuffer blitCommandEncoder];

    NSUInteger offset = (_outputRect.origin.y * _sourceBytesPerRow) + _outputRect.origin.x * 4 /* 4 bpp */;
    NSUInteger len    = _sourceBuffer.length - (_outputRect.origin.y * _sourceBytesPerRow);
    [bce copyFromBuffer:_sourceBuffer sourceOffset:offset sourceBytesPerRow:_sourceBytesPerRow sourceBytesPerImage:len sourceSize:size
              toTexture:texture destinationSlice:0 destinationLevel:0 destinationOrigin:zero];
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
    id<MTLBuffer> source;
    if (_intermediate != nil) {
        if (BufferOptionMustCopy(_options)) {
            memcpy(_intermediate.contents, _buffer, _bufferLenBytes);
        } else {
            memcpy(_intermediate.contents, _sourceBuffer.contents, _sourceBuffer.length);
        }
        source = _intermediate;
    } else {
        if (BufferOptionMustCopy(_options)) {
            memcpy(_sourceBuffer.contents, _buffer, _bufferLenBytes);
        }
        source = _sourceBuffer;
    }
    
    MTLOrigin orig = {.x = _outputRect.origin.x, .y = _outputRect.origin.y};
    [_converter convertFromBuffer:source sourceOrigin:orig sourceBytesPerRow:_sourceBytesPerRow
                        toTexture:texture commandBuffer:commandBuffer];
}

@end
