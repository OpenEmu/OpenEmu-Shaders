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

#import "SlangShader.h"
#import <OpenEmuShaders/OpenEmuShaders-Swift.h>
#import "OEShaderPassCompiler.h"
#import "OESourceParser+Private.h"

static NSString *IDToNSString(id obj)
{
    if ([obj isKindOfClass:NSString.class])
        return (NSString *)obj;
    return nil;
}

static OEShaderPassWrap OEShaderPassWrapFromNSString(NSString *wrapMode)
{
    if (wrapMode == nil)
        return OEShaderPassWrapDefault;
    
    if ([wrapMode isEqualToString:@"clamp_to_border"])
        return OEShaderPassWrapBorder;
    else if ([wrapMode isEqualToString:@"clamp_to_edge"])
        return OEShaderPassWrapEdge;
    else if ([wrapMode isEqualToString:@"repeat"])
        return OEShaderPassWrapRepeat;
    else if ([wrapMode isEqualToString:@"mirrored_repeat"])
        return OEShaderPassWrapMirroredRepeat;
    
    NSLog(@"invalid wrap mode %@. Choose from clamp_to_border, clamp_to_edge, repeat or mirrored_repeat", wrapMode);
    
    return OEShaderPassWrapDefault;
}

static OEShaderPassScale OEShaderPassScaleFromNSString(NSString *scale)
{
    if ([scale isEqualToString:@"source"])
        return OEShaderPassScaleInput;
    if ([scale isEqualToString:@"viewport"])
        return OEShaderPassScaleViewport;
    if ([scale isEqualToString:@"absolute"])
        return OEShaderPassScaleAbsolute;
    return OEShaderPassScaleInvalid;
}

static OEShaderPassFilter OEShaderPassFilterFromObject(id obj)
{
    if (obj == nil) {
        return OEShaderPassFilterUnspecified;
    }
    
    if ([obj boolValue]) {
        return OEShaderPassFilterLinear;
    }
    return OEShaderPassFilterNearest;
}

@implementation ShaderPass
{
    NSURL          *_url;
    NSUInteger     _index;
    OESourceParser *_source;
}

- (instancetype)initWithURL:(NSURL *)url
                      index:(NSUInteger)index
                 dictionary:(NSDictionary *)d
{
    if (self = [super init]) {
        _url    = url;
        _index  = index;
        _source = [[OESourceParser alloc] initFromURL:url error:nil];
        
        self.filter   = OEShaderPassFilterFromObject(d[@"filterLinear"]);
        self.wrapMode = OEShaderPassWrapFromNSString(IDToNSString(d[@"wrapMode"]));
        
        id obj = nil;
        
        if ((obj = d[@"frameCountMod"]) != nil) {
            self.frameCountMod = [obj unsignedIntegerValue];
        }
        
        if ((obj = d[@"srgbFramebuffer"]) != nil) {
            self.issRGB = [obj boolValue];
        }
        
        if ((obj = d[@"floatFramebuffer"]) != nil) {
            self.isFloat = [obj boolValue];
        }
        
        if ((obj = d[@"mipmapInput"]) != nil) {
            self.isMipmap = [obj boolValue];
        }
        
        self.alias = IDToNSString(d[@"alias"]);
        if (self.alias == nil || self.alias.length == 0) {
            self.alias = _source.name;
        }
        
        if (d[@"scaleType"] != nil || d[@"scaleTypeX"] != nil || d[@"scaleTypeY"] != nil) {
            // scale
            self.valid  = YES;
            self.scaleX = OEShaderPassScaleInput;
            self.scaleY = OEShaderPassScaleInput;
            CGSize size  = {0};
            CGSize scale = CGSizeMake(1.0, 1.0);
            
            NSString *str = nil;
            if ((str = IDToNSString(d[@"scaleType"])) != nil) {
                self.scaleX = OEShaderPassScaleFromNSString(str);
                self.scaleY = self.scaleX;
            } else {
                if ((str = IDToNSString(d[@"scaleTypeX"])) != nil) {
                    self.scaleX = OEShaderPassScaleFromNSString(str);
                }
                if ((str = IDToNSString(d[@"scaleTypeY"])) != nil) {
                    self.scaleY = OEShaderPassScaleFromNSString(str);
                }
            }
            
            // scale-x
            if ((obj = d[@"scale"] ?: d[@"scaleX"]) != nil) {
                if (self.scaleX == OEShaderPassScaleAbsolute) {
                    size.width = [obj unsignedIntegerValue];
                } else {
                    scale.width = [obj doubleValue];
                }
            }
            
            // scale-y
            if ((obj = d[@"scale"] ?: d[@"scaleY"]) != nil) {
                if (self.scaleY == OEShaderPassScaleAbsolute) {
                    size.height = [obj unsignedIntegerValue];
                } else {
                    scale.height = [obj doubleValue];
                }
            }
            
            self.size  = size;
            self.scale = scale;
        }
    }
    return self;
}

- (OESourceParser *)source
{
    return _source;
}

- (MTLPixelFormat)format
{
    MTLPixelFormat format = _source.format;
    if (format == MTLPixelFormatInvalid) {
        if (_issRGB) {
            format = MTLPixelFormatBGRA8Unorm_sRGB;
        } else if (_isFloat) {
            format = MTLPixelFormatRGBA16Float;
        } else {
            format = MTLPixelFormatBGRA8Unorm;
        }
    }
    return format;
}

@end

@implementation ShaderLUT
{
}

- (instancetype)initWithURL:(NSURL *)url
                       name:(NSString *)name
                 dictionary:(NSDictionary *)d
{
    if (self = [super init]) {
        _url  = url;
        _name = name;
        
        self.filter   = OEShaderPassFilterFromObject(d[@"linear"]);
        self.wrapMode = OEShaderPassWrapFromNSString(IDToNSString(d[@"wrapMode"]));
        
        id obj = nil;
        if ((obj = d[@"mipmapInput"]) != nil) {
            self.isMipmap = [obj boolValue];
        }
    }
    return self;
}


@end

@implementation SlangShader
{
    NSURL                                                *_url;
    NSMutableArray<ShaderPass *>                         *_passes;
    NSMutableArray<ShaderLUT *>                          *_luts;
    NSMutableArray<OEShaderParameter *>                  *_parameters;
    NSMutableDictionary<NSString *, OEShaderParameter *> *_parametersMap;
    OEShaderPassCompiler                                 *_compiler;
    
}

- (instancetype)initFromURL:(NSURL *)url error:(NSError **)error
{
    if (self = [super init]) {
        _url           = url;
        _parameters    = [NSMutableArray new];
        _parametersMap = [NSMutableDictionary new];
        
        NSURL *base                     = [url URLByDeletingLastPathComponent];
        
        NSError                      *err;
        NSDictionary<NSString *, id> *d = [ShaderConfigSerialization configFromURL:url error:&err];
        if (err != nil) {
            if (error != nil) {
                *error = err;
            }
            return nil;
        }
        
        NSArray *passes = d[@"passes"];
        _passes = [NSMutableArray arrayWithCapacity:passes.count];
        
        NSUInteger        i = 0;
        for (NSDictionary *spec in passes) {
            NSString *path = spec[@"shader"];
            _passes[i] = [[ShaderPass alloc] initWithURL:[NSURL URLWithString:path
                                                                relativeToURL:base]
                                                   index:i
                                              dictionary:spec];
            i++;
        }
        
        // parse look-up textures
        NSDictionary < NSString *, NSDictionary * > *textures = d[@"textures"];
        if (textures != nil) {
            _luts = [NSMutableArray arrayWithCapacity:textures.count];
            i     = 0;
            for (NSString *key in textures.keyEnumerator) {
                NSDictionary *spec = textures[key];
                NSString     *path = spec[@"path"];
                _luts[i] = [[ShaderLUT alloc] initWithURL:[NSURL URLWithString:path
                                                                 relativeToURL:base]
                                                     name:key
                                               dictionary:spec];
                i++;
            }
        }
        
        // collect parameters
        i = 0;
        for (ShaderPass *pass in _passes) {
            NSDictionary < NSString *, OEShaderParameter * > *params = pass.source.parameters;
            for (OEShaderParameter                           *param in params.objectEnumerator) {
                OEShaderParameter *existing = _parametersMap[param.name];
                if (existing != nil && ![param isEqual:existing]) {
                    // TODO(SGC) conflicting parameters
                    assert("conflicting parameters");
                }
                [_parameters addObject:param];
                _parametersMap[param.name] = param;
            }
            i++;
        }
        
        // resolve overrides from .plist
        NSDictionary < NSString *, NSNumber * > *params = d[@"parameters"];
        if (params != nil) {
            for (NSString *name in params) {
                OEShaderParameter *existing = _parametersMap[name];
                if (existing) {
                    existing.initial = [params[name] floatValue];
                    existing.value   = [params[name] floatValue];
                }
            }
        }
        
        _compiler = [[OEShaderPassCompiler alloc] initWithShaderModel:self];
    }
    return self;
}

- (BOOL)buildPass:(NSUInteger)passNumber
     metalVersion:(NSUInteger)version
    passSemantics:(ShaderPassSemantics *)passSemantics
     passBindings:(ShaderPassBindings *)passBindings
           vertex:(NSString **)vsrc
         fragment:(NSString **)fsrc
{
    
    return [_compiler buildPass:passNumber
                   metalVersion:version
                  passSemantics:passSemantics
                   passBindings:passBindings
                         vertex:vsrc
                       fragment:fsrc];
}

@end
