//
//  OpenEmuShadersTests.m
//  OpenEmuShadersTests
//
//  Created by Stuart Carnie on 5/3/19.
//  Copyright © 2019 OpenEmu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSScanner+Extensions.h"

@interface OpenEmuShadersTests : XCTestCase

@end

@implementation OpenEmuShadersTests

- (void)testNSScannerScanQuotedString {
    NSScanner *scan = [NSScanner scannerWithString:@"3.0 \"hello there\" YES"];

    double f = 0;
    XCTAssertTrue([scan scanDouble:&f]);
    XCTAssertEqual(f, 3.0);

    NSString *s = nil;
    XCTAssertTrue([scan scanQuotedString:&s]);
    XCTAssertTrue([s isEqualToString:@"hello there"]);

    XCTAssertTrue([scan scanCharactersFromSet:NSCharacterSet.alphanumericCharacterSet intoString:&s]);
    XCTAssertTrue([s isEqualToString:@"YES"]);
}


- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
