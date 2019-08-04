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
#import "logging.h"

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
    
    os_log_debug(OE_LOG_DEFAULT, "invalid wrap mode %{public}@. Choose from clamp_to_border, clamp_to_edge, repeat or mirrored_repeat", wrapMode);
    
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
                      error:(NSError **)error
{
    if (self = [super init]) {
        _url    = url;
        _index  = index;
        NSError *err;
        _source = [[OESourceParser alloc] initFromURL:url error:&err];
        if (err != nil) {
            if (error != nil) {
                *error = err;
            }
            os_log_error(OE_LOG_DEFAULT, "error reading source '%@': %@", url.absoluteString, err.localizedDescription);
            return nil;
        }
        
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
    NSMutableArray<OEShaderParamGroup *>                 *_parameterGroups;
    OEShaderPassCompiler                                 *_compiler;
    NSUInteger                                           _historyCount;
}

- (instancetype)initFromURL:(NSURL *)url error:(NSError **)error
{
    if (self = [super init]) {
        _url             = url;
        _parameters      = [NSMutableArray new];
        _parametersMap   = [NSMutableDictionary new];
        _parameterGroups = [NSMutableArray new];
        
        NSError                      *err;
        NSDictionary<NSString *, id> *d = [ShaderConfigSerialization configFromURL:url error:&err];
        if (err != nil) {
            if (error != nil) {
                *error = err;
            }
            return nil;
        }
        
        NSURL *base     = [url URLByDeletingLastPathComponent];
        NSArray *passes = d[@"passes"];
        _passes = [NSMutableArray arrayWithCapacity:passes.count];
        
        NSUInteger        i = 0;
        for (NSDictionary *spec in passes) {
            NSString *path = spec[@"shader"];
            ShaderPass *pass = [[ShaderPass alloc] initWithURL:[NSURL URLWithString:path
                                                                      relativeToURL:base]
                                                         index:i
                                                    dictionary:spec
                                                         error:&err];
            if (err != nil) {
                if (error != nil) {
                    *error = err;
                }
                return nil;
            }
            
            _passes[i] = pass;
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
            for (OEShaderParameter *param in pass.source.parameters) {
                OEShaderParameter *existing = _parametersMap[param.name];
                if (existing != nil) {
                    if (![param isEqual:existing]) {
                        // TODO: return error
                        assert("conflicting parameters");
                    }
                    // it is a value duplicate, so skip
                    continue;
                }
                [_parameters addObject:param];
                _parametersMap[param.name] = param;
            }
            i++;
        }
        
        // resolve overrides from config
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
        
        // resolve override groups from config
        NSDictionary<NSString *, NSDictionary<NSString *, id> *> *groups = d[@"parameterGroups"];

        // create empty group
        OEShaderParamGroup *global = [[OEShaderParamGroup alloc] initWithName:@"default" desc:@""];
        id obj;
        BOOL hasDefault = NO;
        if ((obj = groups[@"hasDefault"]) != nil) {
            hasDefault = [obj boolValue];
        }
        
        if (!hasDefault)
        {
            // default group comes first if not overridden
            [_parameterGroups addObject:global];
        }
        
        for (NSString *name in groups[@"names"]) {
            NSDictionary<NSString *, id> *group = groups[name];
            
            if (hasDefault && [name isEqualToString:@"default"])
            {
                [_parameterGroups addObject:global];
                if (![group[@"desc"] isEqualToString:@"default"])
                {
                    // user specifed a custom description default_group_desc = "..."
                    global.desc = group[@"desc"];
                }
                
                continue;
            }

            
            OEShaderParamGroup *pg = [[OEShaderParamGroup alloc] initWithName:name desc:group[@"desc"]];
            NSMutableArray<OEShaderParameter *> *params = [NSMutableArray new];
            
            for (NSString *param in group[@"parameters"]) {
                OEShaderParameter *p = _parametersMap[param];
                if (p) {
                    p.group = pg.desc;
                    [params addObject:p];
                }
            }
            if (params.count > 0)
            {
                pg.parameters = params;
                [_parameterGroups addObject:pg];
            }
        }
        
        if (_parameterGroups.count > 1)
        {
            // collect remaining parameters into the global group
            NSMutableArray<OEShaderParameter *> *gparams = [NSMutableArray new];
            for (OEShaderParameter *param in _parameters) {
                if ([param.group isEqualToString:@""])
                {
                    param.group = global.desc; // it may have been given a new description
                    [gparams addObject:param];
                }
            }
            global.parameters = gparams;
            
            // sort the primary list of parameters into groups
            _parameters = [NSMutableArray new];
            for (OEShaderParamGroup *g in _parameterGroups) {
                [_parameters addObjectsFromArray:g.parameters];
            }
        }
        else
        {
            global.parameters = _parameters;
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

- (void)setHistoryCount:(NSUInteger)historyCount {
    _historyCount = historyCount;
}

@end
