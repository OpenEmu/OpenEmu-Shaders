//
// Created by Stuart Carnie on 2019-05-04.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "spirv.h"

@interface ShaderProgram : NSObject

@property (nonatomic, readonly) SpvId const *spirv;
@property (nonatomic, readonly) size_t spirvLength;

@end

/*!
 * SlangCompiler is responsible for compiling a glsl shader program into SPIRV
 */
@interface SlangCompiler : NSObject

- (ShaderProgram *)compileVertex:(NSString *)src error:(NSError **)error;
- (ShaderProgram *)compileFragment:(NSString *)src error:(NSError **)error;

@end
