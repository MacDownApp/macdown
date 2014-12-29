//
//  MPColorTests.m
//  MacDown
//
//  Created by Tzu-ping Chung on 29/12.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSColor+HTML.h"

@interface MPColorTests : XCTestCase
@end


@implementation MPColorTests

- (void)testHexStringToColor
{
    NSColor *color = [NSColor colorWithHTMLName:@"#123456"];
    CGFloat r, g, b;
    [color getRed:&r green:&g blue:&b alpha:NULL];
    XCTAssertEqual(r, 0x12 / 255.0);
    XCTAssertEqual(g, 0x34 / 255.0);
    XCTAssertEqual(b, 0x56 / 255.0);
}

- (void)testColorNameToColor
{
    NSColor *color = [NSColor colorWithHTMLName:@"red"];
    CGFloat r, g, b;
    [color getRed:&r green:&g blue:&b alpha:NULL];
    XCTAssertEqual(r, 1.0);
    XCTAssertEqual(g, 0.0);
    XCTAssertEqual(b, 0.0);
}

@end
