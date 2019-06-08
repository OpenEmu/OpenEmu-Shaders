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
    BufferOptionNone        = (0 << 0),
    BufferOptionNative      = (1 << 0), // buffer is native BGRA8
    BufferOptionOriginZero  = (1 << 1), // origin at (0, 0)
    BufferOptionNoCopy      = (1 << 2), // buffer memory
    
    // standard options
    
    BufferOptionNativeZeroNoCopy    = (BufferOptionNative | BufferOptionOriginZero | BufferOptionNoCopy),
    BufferOptionNativeNoCopy        = (BufferOptionNative | BufferOptionNoCopy),
    BufferOptionNativeZeroCopy      = (BufferOptionNative | BufferOptionOriginZero),
    BufferOptionConvertZeroNoCopy   = (BufferOptionOriginZero | BufferOptionNoCopy),
    BufferOptionConvertNoCopy       = (BufferOptionNoCopy),
    BufferOptionConvertZeroCopy     = (BufferOptionOriginZero),
    BufferOptionConvertCopy         = BufferOptionNone,
};

BufferOption BufferOptionMustCopy(BufferOption o) {
    return (o & BufferOptionNoCopy) == BufferOptionNone;
}

@implementation OEPixelBuffer {
    id<MTLDevice>       _device;
    MTLPixelConverter *_converter;
    
    OEMTLPixelFormat    _format;
    NSUInteger          _srcBytesPerRow;
    id<MTLBuffer>       _srcBuffer;
    CGSize              _sourceSize;
    CGRect              _outputRect;
    BufferOption        _options;
    
    // for unaligned buffers
    uint8_t             *_buffer;
    size_t              _bufferLenBytes;
}

#pragma mark - public APIs

- (void)setOutputRect:(CGRect)rect {
    if (CGRectEqualToRect(_outputRect, rect)) {
        return;
    }
    
    _outputRect = rect;
    
    if (CGPointEqualToPoint(_outputRect.origin, CGPointZero)) {
        _options |= BufferOptionOriginZero;
    } else {
        _options &= ~BufferOptionOriginZero;
    }
}

- (void *)contents {
    return _buffer ?: _srcBuffer.contents;
}

#pragma mark - internal APIs

- (instancetype)initWithDevice:(id<MTLDevice>)device converter:(MTLPixelConverter *)converter
{
    if (!(self = [super init])) {
        return nil;
    }
    
    _device     = device;
    _converter  = converter;
    
    return self;
}

- (void)setFormat:(OEMTLPixelFormat)format {
    if (format == _format) {
        return;
    }
    
    _format = format;
    switch (format) {
        case OEMTLPixelFormatRGBA8Unorm:
        case OEMTLPixelFormatR5G5B5A1Unorm:
        case OEMTLPixelFormatB5G6R5Unorm:
        case OEMTLPixelFormatBGRA4Unorm:
            _options &= ~BufferOptionNative;
            break;
            
        case OEMTLPixelFormatBGRA8Unorm:
        case OEMTLPixelFormatBGRX8Unorm:
            _options |= BufferOptionNative;
            break;
            
        default:
            NSParameterAssert("unsupported format");
            break;
    }
}

- (id<MTLBuffer>)allocateBufferWithFormat:(OEMTLPixelFormat)format height:(NSUInteger)height bytesPerRow:(NSUInteger)bytesPerRow bytes:(void *)pointer
{
    _srcBytesPerRow = bytesPerRow;
    _sourceSize = CGSizeMake(bytesPerRow / OEMTLPixelFormatToBPP(format), height);
    [self setFormat:format];
    
    if ((uintptr_t)pointer % 4096 == 0) {
        _options |= BufferOptionNoCopy;
        _srcBuffer = [_device newBufferWithBytesNoCopy:pointer length:height * bytesPerRow options:MTLResourceStorageModeShared deallocator:nil];
    } else {
        _options &= ~BufferOptionNoCopy;
        _buffer = pointer;
        _bufferLenBytes = bytesPerRow * height;
        _srcBuffer = [_device newBufferWithLength:height * bytesPerRow options:MTLResourceStorageModeShared];
    }

    
    return _srcBuffer;
}

- (id<MTLBuffer>)allocateBufferWithFormat:(OEMTLPixelFormat)format height:(NSUInteger)height bytesPerRow:(NSUInteger)bytesPerRow
{
    _options |= BufferOptionNoCopy;
    _srcBytesPerRow = bytesPerRow;
    _sourceSize = CGSizeMake(bytesPerRow / OEMTLPixelFormatToBPP(format), height);
    [self setFormat:format];
    
    _srcBuffer = [_device newBufferWithLength:height * bytesPerRow options:MTLResourceStorageModeShared];
    return _srcBuffer;
}

- (void)prepareWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer texture:(id<MTLTexture>)texture
{
    switch (_options) {
        case BufferOptionNativeNoCopy:
        case BufferOptionNativeZeroNoCopy:
            [self OE_updateNativeFullCommandBuffer:commandBuffer texture:texture];
            break;
            
        case BufferOptionNativeZeroCopy:
            if (texture.storageMode == MTLStorageModePrivate) {
                // replaceRegion not supported for private storage mode
                [self OE_updateNativeFullCommandBuffer:commandBuffer texture:texture];
            } else {
                [texture replaceRegion:MTLRegionMake2D(_outputRect.origin.x, _outputRect.origin.y, _outputRect.size.width, _outputRect.size.height)
                           mipmapLevel:0
                             withBytes:_buffer
                           bytesPerRow:_srcBytesPerRow];
            }
            break;
            
        case BufferOptionConvertNoCopy:
        case BufferOptionConvertZeroNoCopy: {
            MTLOrigin orig = {.x = _outputRect.origin.x, .y = _outputRect.origin.y};
            [_converter convertFromBuffer:_srcBuffer sourceFormat:_format sourceOrigin:orig sourceBytesPerRow:_srcBytesPerRow
                                toTexture:texture commandBuffer:commandBuffer];
            break;
        }
        
        case BufferOptionConvertCopy:
        case BufferOptionConvertZeroCopy: {
            memcpy(_srcBuffer.contents, _buffer, _bufferLenBytes);
            MTLOrigin orig = {.x = _outputRect.origin.x, .y = _outputRect.origin.y};
            [_converter convertFromBuffer:_srcBuffer sourceFormat:_format sourceOrigin:orig sourceBytesPerRow:_srcBytesPerRow
                                toTexture:texture commandBuffer:commandBuffer];
            break;
        }

        default:
            NSAssert1(false, @"unsupported options: %lu", _options);
    }
}

- (void)OE_updateNativeFullCommandBuffer:(id<MTLCommandBuffer>)commandBuffer texture:(id<MTLTexture>)texture
{
    if (BufferOptionMustCopy(_options)) {
        memcpy(_srcBuffer.contents, _buffer, _bufferLenBytes);
    }
    
    MTLSize                   size = {.width = (NSUInteger)_outputRect.size.width, .height = (NSUInteger)_outputRect.size.height, .depth = 1};
    MTLOrigin                 zero = {0};
    id<MTLBlitCommandEncoder> bce  = [commandBuffer blitCommandEncoder];
    
    NSUInteger offset = (_outputRect.origin.y * _srcBytesPerRow) + _outputRect.origin.x * 4 /* 4 bpp */;
    NSUInteger len    = _srcBuffer.length - (_outputRect.origin.y * _srcBytesPerRow);
    [bce copyFromBuffer:_srcBuffer sourceOffset:offset sourceBytesPerRow:_srcBytesPerRow sourceBytesPerImage:len sourceSize:size
              toTexture:texture destinationSlice:0 destinationLevel:0 destinationOrigin:zero];
    [bce endEncoding];
}

@end
