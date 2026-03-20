//
//  MPPreferencesTests.m
//  MPPreferencesTests
//
//  Created by Tzu-ping Chung  on 6/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MPPreferences.h"

@interface MPPreferencesTests : XCTestCase
@property MPPreferences *preferences;
@property NSDictionary *oldFontInfo;
@end


@implementation MPPreferencesTests

- (void)setUp
{
    [super setUp];
    self.preferences = [MPPreferences sharedInstance];
    self.oldFontInfo = [self.preferences.editorBaseFontInfo copy];

}

- (void)tearDown
{
    self.preferences.editorBaseFontInfo = self.oldFontInfo;
    [self.preferences synchronize];
    [super tearDown];
}

- (void)testFont
{
    NSFont *font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
    self.preferences.editorBaseFont = font;

    XCTAssertTrue([self.preferences synchronize],
                  @"Failed to synchronize user defaults.");

    NSFont *result = [self.preferences.editorBaseFont copy];
    XCTAssertEqualObjects(font, result,
                          @"Preferences not preserving font info correctly.");
}

@end
