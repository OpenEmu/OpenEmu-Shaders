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

#import "ShaderParameter.h"
#import "ShaderPassSemantics.h"

@interface ShaderPass : NSObject

@property (nonatomic, readwrite) NSURL *url;
@property (nonatomic, readwrite) NSUInteger frameCountMod;
@property (nonatomic, readwrite) ShaderPassScale scaleX;
@property (nonatomic, readwrite) ShaderPassScale scaleY;
@property (nonatomic, readwrite) SlangFormat format;
@property (nonatomic, readwrite) ShaderPassFilter filter;
@property (nonatomic, readwrite) ShaderPassWrap wrapMode;
@property (nonatomic, readwrite) CGSize scale;
@property (nonatomic, readwrite) CGSize size;
@property (nonatomic, readwrite) BOOL valid;
@property (nonatomic, readwrite) BOOL isFloat;
@property (nonatomic, readwrite) BOOL issRGB;
@property (nonatomic, readwrite) BOOL isMipmap;
@property (nonatomic, readwrite) BOOL isFeedback;
@property (nonatomic, readwrite) NSString *alias;

@end

@interface ShaderLUT : NSObject

@property (nonatomic, readwrite) NSURL *url;
@property (nonatomic, readwrite) NSString *name;
@property (nonatomic, readwrite) ShaderPassWrap wrapMode;
@property (nonatomic, readwrite) BOOL isMipmap;
@property (nonatomic, readwrite) ShaderPassFilter filter;

@end

@interface SlangShader : NSObject

- (instancetype)initFromURL:(NSURL *)url;

@property (nonatomic, readonly) NSArray<ShaderPass *> *passes;
@property (nonatomic, readonly) NSArray<ShaderParameter *> *parameters;
@property (nonatomic, readonly) NSArray<ShaderLUT *> *luts;
@property (nonatomic, readonly) NSUInteger historySize;

- (BOOL)buildPass:(NSUInteger)passNumber
     metalVersion:(NSUInteger)version
    passSemantics:(ShaderPassSemantics *)passSemantics
     passBindings:(ShaderPassBindings *)passBindings
           vertex:(NSString **)vsrc
         fragment:(NSString **)fsrc;


@end
