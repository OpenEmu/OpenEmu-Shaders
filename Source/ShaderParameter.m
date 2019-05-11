//
// Created by Stuart Carnie on 2019-05-04.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#include "ShaderParameter.h"

@implementation ShaderParameter {
    NSUInteger _index;
    float _value;
}

- (instancetype)initWithPath:(NSString *)path
                       index:(NSUInteger)index
                  dictionary:(NSDictionary *)d {
    if (self = [super init]) {
        _index = index;


    }
    return self;
}

- (float *)valuePtr {
    return &_value;
}

- (BOOL)isEqual:(id)object {
    if (object == nil || ![object isKindOfClass:self.class]) {
        return NO;
    }

    ShaderParameter *other = (ShaderParameter *) object;

    return [self.name isEqualToString:other.name] &&
        [self.desc isEqualToString:other.desc] &&
        self.initial == other.initial &&
        self.minimum == other.minimum &&
        self.maximum == other.maximum &&
        self.step == other.step;

}

@end