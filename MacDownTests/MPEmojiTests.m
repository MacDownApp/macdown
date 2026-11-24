//
//  MPEmojiTests.m
//  MacDown
//

#import <XCTest/XCTest.h>
#import "NSString+Emoji.h"

@interface MPEmojiTests : XCTestCase
@end


@implementation MPEmojiTests

- (void)testReplacesKnownShortcodes
{
    NSString *html = @"<p>:rocket: :+1: :-1: :t-rex: :100:</p>";
    NSString *expected = @"<p>🚀 👍 👎 🦖 💯</p>";
    XCTAssertEqualObjects([html stringByReplacingEmojiShortcodes], expected);
}

- (void)testReplacesMultipleOccurrences
{
    NSString *html = @":fire: and :fire:";
    XCTAssertEqualObjects([html stringByReplacingEmojiShortcodes], @"🔥 and 🔥");
}

- (void)testReplacesAdjacentShortcodes
{
    NSString *html = @":rocket::tada:";
    XCTAssertEqualObjects([html stringByReplacingEmojiShortcodes], @"🚀🎉");
}

- (void)testLeavesUnknownShortcodesAlone
{
    NSString *html = @"<p>:not_a_real_one: and 12:30: stay</p>";
    XCTAssertEqualObjects([html stringByReplacingEmojiShortcodes], html);
}

- (void)testLookupIsCaseSensitive
{
    NSString *html = @":ROCKET:";
    XCTAssertEqualObjects([html stringByReplacingEmojiShortcodes], html);
}

- (void)testReplacesInsideInlineElements
{
    NSString *html = @"<em>:tada:</em>";
    XCTAssertEqualObjects([html stringByReplacingEmojiShortcodes], @"<em>🎉</em>");
}

- (void)testReplacesInHeadings
{
    NSString *html = @"<h1 id=\"x\">:fire: heading</h1>";
    XCTAssertEqualObjects([html stringByReplacingEmojiShortcodes],
                          @"<h1 id=\"x\">🔥 heading</h1>");
}

- (void)testSkipsCodeBlocks
{
    NSString *html = @"<pre><code>:tada:</code></pre>";
    XCTAssertEqualObjects([html stringByReplacingEmojiShortcodes], html);
}

- (void)testSkipsMultilineCodeBlocks
{
    NSString *html = @"<pre><code class=\"lang-sh\">echo\n:tada:\n</code></pre>";
    XCTAssertEqualObjects([html stringByReplacingEmojiShortcodes], html);
}

- (void)testSkipsInlineCode
{
    NSString *html = @"<p><code>:smile:</code> :smile:</p>";
    XCTAssertEqualObjects([html stringByReplacingEmojiShortcodes],
                          @"<p><code>:smile:</code> 😄</p>");
}

- (void)testSkipsAttributes
{
    NSString *html = @"<img alt=\":heart:\" src=\"x.png\"> <a href=\":tada:\">x</a>";
    XCTAssertEqualObjects([html stringByReplacingEmojiShortcodes], html);
}

- (void)testStringWithoutShortcodesIsUnchanged
{
    NSString *html = @"<p>plain text</p>";
    XCTAssertEqualObjects([html stringByReplacingEmojiShortcodes], html);
    XCTAssertEqualObjects([@"" stringByReplacingEmojiShortcodes], @"");
}

@end
