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

#import "ShaderPassSemantics.h"

NS_ASSUME_NONNULL_BEGIN

@class OEShaderParameter;

@interface ShaderPass : NSObject

@property (nonatomic, readwrite) NSURL     *url;
@property (nonatomic, readwrite) NSUInteger         frameCountMod;
@property (nonatomic, readwrite) OEShaderPassScale  scaleX;
@property (nonatomic, readwrite) OEShaderPassScale  scaleY;
@property (nonatomic, readwrite) MTLPixelFormat     format;
@property (nonatomic, readwrite) OEShaderPassFilter filter;
@property (nonatomic, readwrite) OEShaderPassWrap   wrapMode;
@property (nonatomic, readwrite) CGSize             scale;
@property (nonatomic, readwrite) CGSize             size;
@property (nonatomic, readwrite) BOOL               valid;
@property (nonatomic, readwrite) BOOL               isFloat;
@property (nonatomic, readwrite) BOOL               issRGB;
@property (nonatomic, readwrite) BOOL               isMipmap;
@property (nonatomic, readwrite) BOOL               isFeedback;
@property (nonatomic, readwrite) NSString           *alias;

@end

@interface ShaderLUT : NSObject

@property (nonatomic, readwrite) NSURL              *url;
@property (nonatomic, readwrite) NSString           *name;
@property (nonatomic, readwrite) OEShaderPassWrap   wrapMode;
@property (nonatomic, readwrite) BOOL               isMipmap;
@property (nonatomic, readwrite) OEShaderPassFilter filter;

@end

@interface ParameterGroup : NSObject

@property (nonatomic, readwrite) NSString                     *name;
@property (nonatomic, readwrite) NSString                     *desc;
@property (nonatomic, readwrite) NSArray<OEShaderParameter *> *parameters;

@end

@interface SlangShader : NSObject

- (nullable instancetype)initFromURL:(NSURL *)url error:(NSError **)error;

@property (nonatomic, readonly, nonnull) NSArray<ShaderPass *>        *passes;
@property (nonatomic, readonly, nonnull) NSArray<OEShaderParameter *> *parameters;
@property (nonatomic, readonly, nonnull) NSArray<ParameterGroup *>    *parameterGroups;
@property (nonatomic, readonly, nonnull) NSArray<ShaderLUT *>         *luts;
@property (nonatomic, readonly) NSUInteger                   historyCount;

- (BOOL)buildPass:(NSUInteger)passNumber
     metalVersion:(NSUInteger)version
    passSemantics:(ShaderPassSemantics *)passSemantics
     passBindings:(ShaderPassBindings *)passBindings
           vertex:(NSString * _Nonnull * _Nonnull)vsrc
         fragment:(NSString * _Nonnull * _Nonnull)fsrc;


@end

NS_ASSUME_NONNULL_END
