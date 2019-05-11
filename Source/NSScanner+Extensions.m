//
// Created by Stuart Carnie on 2019-05-04.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#import "NSScanner+Extensions.h"


@implementation NSScanner (Extensions)

- (BOOL)scanQuotedString:(NSString **)string
{
    if (![self scanString:@"\"" intoString:nil]) {
        return NO;
    }

    if (![self scanUpToString:@"\"" intoString:string]) {
        return NO;
    }

    return [self scanString:@"\"" intoString:nil];
}

@end