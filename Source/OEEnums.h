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

#pragma mark -

typedef NS_ENUM(NSInteger, OEMTLPixelFormat)
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
    OEMTLPixelFormatBGRX8Unorm NS_SWIFT_NAME(bgrx8Unorm), // no alpha
    
    OEMTLPixelFormatCount,
};

#pragma mark - Errors

extern NSErrorDomain const OEShaderErrorDomain;

NS_ERROR_ENUM(OEShaderErrorDomain) {
    OEShaderCompilePreprocessError  = -1,
    OEShaderCompileParseError       = -2,
    OEShaderCompileLinkError        = -3,
};
