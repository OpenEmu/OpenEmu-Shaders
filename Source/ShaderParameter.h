//
// Created by Stuart Carnie on 2019-05-04.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ShaderParameter : NSObject

@property (nonatomic) NSString *name;
@property (nonatomic) NSString *desc;
@property (nonatomic) unsigned long index;
@property (nonatomic) float *valuePtr;
@property (nonatomic) float value;
@property (nonatomic) float minimum;
@property (nonatomic) float initial;
@property (nonatomic) float maximum;
@property (nonatomic) float step;
@property (nonatomic) int pass;

@end
