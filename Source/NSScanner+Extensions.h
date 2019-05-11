//
// Created by Stuart Carnie on 2019-05-04.
// Copyright (c) 2019 OpenEmu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSScanner (Extensions)
- (BOOL)scanQuotedString:(NSString **)string;
@end