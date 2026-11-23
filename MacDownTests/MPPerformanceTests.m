//
//  MPPerformanceTests.m
//  MacDown
//
//  Benchmarks for the budgets in MODERNIZATION_PLAN.md (section 2). Each test
//  both records timings (XCTest `measure`) and asserts a generous hard limit,
//  so a large regression fails the build while normal noise does not.
//
//  Baseline numbers are kept in docs/benchmarks.md.
//

#import <XCTest/XCTest.h>
#import "MPHoedownEngine.h"


@interface MPPerformanceTests : XCTestCase
@property (strong) MPHoedownEngine *engine;
@property (strong) MPMarkdownRenderOptions *options;
@end


/// Builds a realistic Markdown document of about `bytes` bytes: headings,
/// paragraphs with inline markup, lists, tables, and fenced code.
static NSString *MPSyntheticDocument(NSUInteger bytes)
{
    NSString *block =
        @"## Section heading\n\n"
        @"A paragraph with *emphasis*, **strong text**, `inline code`, and a "
        @"[link](http://example.com/path?query=1) to somewhere else. It runs "
        @"long enough to wrap over several lines in a typical editor window.\n\n"
        @"- first item\n- second item with `code`\n    - nested item\n\n"
        @"| Name | Value |\n|------|-------|\n| a | 1 |\n| b | 2 |\n\n"
        @"```python\ndef f(x):\n    return x * 2\n```\n\n";
    NSMutableString *doc = [NSMutableString stringWithCapacity:bytes + 512];
    while (doc.length < bytes)
        [doc appendString:block];
    return doc;
}


@implementation MPPerformanceTests

- (void)setUp
{
    [super setUp];
    self.continueAfterFailure = NO;
    self.engine = [[MPHoedownEngine alloc] init];
    self.options = [[MPMarkdownRenderOptions alloc] init];
    self.options.tables = YES;
    self.options.fencedCode = YES;
    self.options.footnotes = YES;
    self.options.autolink = YES;
    self.options.strikethrough = YES;
    self.options.intraEmphasis = YES;
}

- (NSTimeInterval)secondsToRender:(NSString *)markdown
{
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    MPMarkdownResult *result =
        [self.engine renderMarkdown:markdown options:self.options];
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    XCTAssertGreaterThan(result.html.length, 0u);
    return end - start;
}

- (void)runBenchmarkForBytes:(NSUInteger)bytes limitSeconds:(NSTimeInterval)limit
{
    NSString *doc = MPSyntheticDocument(bytes);
    [self secondsToRender:doc];  // Warm up (loads Prism language tables).

    [self measureBlock:^{
        [self secondsToRender:doc];
    }];

    // Hard limit: best of three runs, to ignore a noisy machine.
    NSTimeInterval best = DBL_MAX;
    for (int i = 0; i < 3; i++)
        best = MIN(best, [self secondsToRender:doc]);
    XCTAssertLessThan(best, limit,
                      @"%lu byte document took %.0f ms (limit %.0f ms)",
                      (unsigned long)bytes, best * 1000, limit * 1000);
}

#pragma mark - Markdown to HTML (plan budget: 1 MB under 500 ms)

- (void)testRender10KB
{
    [self runBenchmarkForBytes:10 * 1024 limitSeconds:0.05];
}

- (void)testRender100KB
{
    [self runBenchmarkForBytes:100 * 1024 limitSeconds:0.1];
}

- (void)testRender1MB
{
    [self runBenchmarkForBytes:1024 * 1024 limitSeconds:0.5];
}

- (void)testRender5MB
{
    [self runBenchmarkForBytes:5 * 1024 * 1024 limitSeconds:2.5];
}

@end
