//
//  MPHTMLTabularizeTests.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 13/7.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSObject+HTMLTabularize.h"


@interface MPHTMLTabularizeTests : XCTestCase
@end


@implementation MPHTMLTabularizeTests

- (void)testString
{
    NSString *string = @"Foobar";
    XCTAssertEqualObjects([string HTMLTable], @"Foobar", @"String");
}

- (void)testNumber
{
    NSNumber *number = @10;
    XCTAssertEqualObjects([number HTMLTable], @"10", @"Integer");

    number = @3.14;
    XCTAssertEqualObjects([number HTMLTable], @"3.14", @"Float");
}

- (void)testArray
{
    NSArray *array = @[@"Foo", @42, @2.71828, [NSNull null]];
    NSString *expected =
        @"<table><tbody><tr><td>Foo</td><td>42</td><td>2.71828</td><td></td>"
        @"</tr></tbody></table>";

    XCTAssertEqualObjects([array HTMLTable], expected, @"Array");
}

- (void)testDictionary
{
    NSDictionary *dict = @{@"Foo": @"Bar", @"Pi": @3.141592654, @2.72: @"e",
                           @"Info": @[@"Moo"]};
    NSString *expected =
        @"<table><thead><tr><th>Info</th><th>Foo</th><th>Pi</th><th>2.72</th>"
        @"</tr></thead><tbody><tr><td><table><tbody><tr><td>Moo</td></tr>"
        @"</tbody></table></td><td>Bar</td><td>3.141592654</td><td>e</td></tr>"
        @"</tbody></table>";

    XCTAssertEqualObjects([dict HTMLTable], expected, @"Dictionary");
}

@end
