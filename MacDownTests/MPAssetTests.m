//
//  MPAssetTests.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 13/7.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MPAsset.h"


@interface MPAsset ()
@property (readonly, nonatomic) NSString *typeName;
@end


@interface MPAssetTests : XCTestCase
@property (strong) NSBundle *bundle;
@end


@implementation MPAssetTests

- (void)setUp
{
    [super setUp];
    self.bundle = [NSBundle bundleForClass:[self class]];
}

- (void)testDefaultAssetType
{
    MPAsset *asset = [[MPAsset alloc] init];
    XCTAssertEqualObjects(asset.typeName, @"text/plain");

    MPStyleSheet *css = [[MPStyleSheet alloc] init];
    XCTAssertEqualObjects(css.typeName, @"text/css");

    MPScript *script = [[MPScript alloc] init];
    XCTAssertEqualObjects(script.typeName, @"text/javascript");
}

- (void)testAssetNone
{
    XCTAssertNil([[[MPScript alloc] init] htmlForOption:MPAssetNone],
                 @"Init and NULL rendering");
}

- (void)testAssetConvinienceAndEmbedded
{
    NSURL *url = [self.bundle URLForResource:@"test" withExtension:@"txt"];
    MPScript *script = [MPScript assetWithURL:url andType:@"text/plain"];

    NSString *expected =
        @"<script type=\"text/plain\">\nFoobar\n</script>";
    XCTAssertEqualObjects([script htmlForOption:MPAssetEmbedded], expected,
                          @"Convinience and embedded");
}

- (void)testAssetInitAndFullLink
{
    NSURL *url = [self.bundle URLForResource:@"test" withExtension:@"txt"];
    MPScript *script = [[MPScript alloc] initWithURL:url
                                             andType:@"text/plain"];
    NSString *expected = @"<script type=\"text/plain\" src=\"%@\"></script>";
    expected = [NSString stringWithFormat:expected, url.absoluteString];
    XCTAssertEqualObjects([script htmlForOption:MPAssetFullLink], expected,
                          @"Convinience and full link");

}

- (void)testCSS
{
    NSURL *url = [self.bundle URLForResource:@"test" withExtension:@"css"];
    MPStyleSheet *ss = [MPStyleSheet CSSWithURL:url];

    NSString *linkTag =
        @"<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\">";
    linkTag = [NSString stringWithFormat:linkTag, url.absoluteString];
    NSString *styleTag =
        @"<style type=\"text/css\">\nbody { font-size: 15px; }\n</style>";
    XCTAssertNil([ss htmlForOption:MPAssetNone], @"CSS, NULL rendering");
    XCTAssertEqualObjects([ss htmlForOption:MPAssetEmbedded], styleTag,
                          @"CSS, embedded");
    XCTAssertEqualObjects([ss htmlForOption:MPAssetFullLink], linkTag,
                          @"CSS, full link");
}

- (void)testJavaScript
{
    NSURL *url = [self.bundle URLForResource:@"test" withExtension:@"js"];
    MPScript *script = [MPScript javaScriptWithURL:url];

    NSString *linkedTag =
        @"<script type=\"text/javascript\" src=\"%@\"></script>";
    linkedTag = [NSString stringWithFormat:linkedTag, url.absoluteString];
    NSString *embeddedTag =
        @"<script type=\"text/javascript\">\nconsole.log('test');\n</script>";
    XCTAssertNil([script htmlForOption:MPAssetNone], @"JS, NULL rendering");
    XCTAssertEqualObjects([script htmlForOption:MPAssetEmbedded], embeddedTag,
                          @"JS, embedded");
    XCTAssertEqualObjects([script htmlForOption:MPAssetFullLink], linkedTag,
                          @"JS, full link");
}

- (void)testEmbedded
{
    NSURL *url = [self.bundle URLForResource:@"test" withExtension:@"js"];
    MPEmbeddedScript *script =
        [MPEmbeddedScript assetWithURL:url andType:kMPMathJaxConfigType];

    NSString *tag = @"<script type=\"text/x-mathjax-config\">\n"
                    @"console.log('test');\n</script>";
    XCTAssertNil([script htmlForOption:MPAssetNone], @"JS, NULL rendering");
    XCTAssertEqualObjects([script htmlForOption:MPAssetEmbedded], tag,
                          @"Embedded");
    XCTAssertEqualObjects([script htmlForOption:MPAssetFullLink], tag,
                          @"Forced embedded");
}

@end
