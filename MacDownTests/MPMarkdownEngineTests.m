//
//  MPMarkdownEngineTests.m
//  MacDown
//
//  Characterization ("golden file") tests for the Markdown engine. They pin
//  the HTML that the current engine produces for a corpus of documents, so
//  that replacing the parser (modernization plan, Phase 2) shows every output
//  difference for review.
//
//  Corpus:  MacDownTests/Snapshots/corpus/NAME.md
//  Goldens: MacDownTests/Snapshots/golden/NAME.<variant>.html
//
//  To (re)record goldens run the tests with
//      TEST_RUNNER_MACDOWN_RECORD_SNAPSHOTS=<absolute path to .../Snapshots/golden>
//  and review the diff before committing.
//

#import <XCTest/XCTest.h>
#import <hoedown/document.h>
#import <hoedown/html.h>
#import "../MacDown/Code/Extension/hoedown_html_patch.h"
#import "MPHoedownEngine.h"


@interface MPMarkdownEngineTests : XCTestCase
@property (strong) MPHoedownEngine *engine;
@property (strong) NSBundle *bundle;
@end


@implementation MPMarkdownEngineTests

- (void)setUp
{
    [super setUp];
    self.engine = [[MPHoedownEngine alloc] init];
    self.bundle = [NSBundle bundleForClass:[self class]];
}

#pragma mark - Option sets

/// What a new MacDown install uses.
- (MPMarkdownRenderOptions *)defaultOptions
{
    MPMarkdownRenderOptions *o = [[MPMarkdownRenderOptions alloc] init];
    o.extensions = HOEDOWN_EXT_TABLES | HOEDOWN_EXT_FENCED_CODE
                 | HOEDOWN_EXT_FOOTNOTES;
    return o;
}

/// Every optional feature switched on.
- (MPMarkdownRenderOptions *)extendedOptions
{
    MPMarkdownRenderOptions *o = [[MPMarkdownRenderOptions alloc] init];
    o.extensions = HOEDOWN_EXT_TABLES | HOEDOWN_EXT_FENCED_CODE
                 | HOEDOWN_EXT_FOOTNOTES | HOEDOWN_EXT_AUTOLINK
                 | HOEDOWN_EXT_STRIKETHROUGH | HOEDOWN_EXT_UNDERLINE
                 | HOEDOWN_EXT_HIGHLIGHT | HOEDOWN_EXT_QUOTE
                 | HOEDOWN_EXT_SUPERSCRIPT | HOEDOWN_EXT_MATH
                 | HOEDOWN_EXT_MATH_EXPLICIT | HOEDOWN_EXT_NO_INTRA_EMPHASIS;
    o.rendererFlags = HOEDOWN_HTML_USE_TASK_LIST | HOEDOWN_HTML_HARD_WRAP
                    | HOEDOWN_HTML_BLOCKCODE_LINE_NUMBERS;
    o.smartyPants = YES;
    o.rendersTOC = YES;
    o.detectsFrontMatter = YES;
    return o;
}

#pragma mark - Corpus

- (NSString *)corpusDirectory
{
    return [[self.bundle resourcePath]
            stringByAppendingPathComponent:@"Snapshots/corpus"];
}

- (NSString *)goldenDirectory
{
    return [[self.bundle resourcePath]
            stringByAppendingPathComponent:@"Snapshots/golden"];
}

- (NSArray<NSString *> *)corpusNames
{
    NSArray *files = [[NSFileManager defaultManager]
                      contentsOfDirectoryAtPath:[self corpusDirectory]
                      error:NULL];
    NSMutableArray *names = [NSMutableArray array];
    for (NSString *file in files)
    {
        if ([file.pathExtension isEqualToString:@"md"])
            [names addObject:[file stringByDeletingPathExtension]];
    }
    return [names sortedArrayUsingSelector:@selector(compare:)];
}

- (void)checkVariant:(NSString *)variant
             options:(MPMarkdownRenderOptions *)options
{
    NSString *recordDir =
        NSProcessInfo.processInfo.environment[@"MACDOWN_RECORD_SNAPSHOTS"];
    NSArray *names = [self corpusNames];
    XCTAssertGreaterThan(names.count, 10u, @"Corpus is missing");

    for (NSString *name in names)
    {
        NSString *path = [[self corpusDirectory]
                          stringByAppendingPathComponent:
                          [name stringByAppendingString:@".md"]];
        NSString *markdown = [NSString stringWithContentsOfFile:path
                              encoding:NSUTF8StringEncoding error:NULL];
        XCTAssertNotNil(markdown, @"Cannot read %@", name);

        NSString *html = [self.engine renderMarkdown:markdown
                                             options:options].html;
        XCTAssertNotNil(html, @"%@ (%@) produced no HTML", name, variant);

        NSString *goldenName =
            [NSString stringWithFormat:@"%@.%@.html", name, variant];
        if (recordDir.length)
        {
            NSString *out = [recordDir stringByAppendingPathComponent:goldenName];
            [html writeToFile:out atomically:YES
                     encoding:NSUTF8StringEncoding error:NULL];
            continue;
        }

        NSString *goldenPath = [[self goldenDirectory]
                                stringByAppendingPathComponent:goldenName];
        NSString *golden = [NSString stringWithContentsOfFile:goldenPath
                            encoding:NSUTF8StringEncoding error:NULL];
        XCTAssertNotNil(golden, @"No golden file for %@", goldenName);
        XCTAssertEqualObjects(html, golden,
                              @"Output changed for %@ (%@)", name, variant);
    }
}

#pragma mark - Tests

- (void)testCorpusWithDefaultOptions
{
    [self checkVariant:@"default" options:[self defaultOptions]];
}

- (void)testCorpusWithAllExtensions
{
    [self checkVariant:@"extended" options:[self extendedOptions]];
}

- (void)testRenderingHasNoHiddenState
{
    NSString *a = @"# A\n\n```python\nx = 1\n```\n";
    NSString *b = @"plain paragraph";
    MPMarkdownRenderOptions *o = [self defaultOptions];

    NSString *first = [self.engine renderMarkdown:a options:o].html;
    [self.engine renderMarkdown:b options:o];
    NSString *second = [self.engine renderMarkdown:a options:o].html;
    XCTAssertEqualObjects(first, second);
}

- (void)testFencedCodeReportsLanguagesWithDependencies
{
    MPMarkdownRenderOptions *o = [self defaultOptions];
    MPMarkdownResult *r = [self.engine
        renderMarkdown:@"```cpp\nint x;\n```\n\n```js\nvar y;\n```\n"
        options:o];
    XCTAssertTrue([r.languages containsObject:@"cpp"],
                  @"Got %@", r.languages);
    // C++ requires C, and the "js" alias maps to "javascript".
    XCTAssertTrue([r.languages containsObject:@"c"], @"Got %@", r.languages);
    XCTAssertTrue([r.languages containsObject:@"javascript"],
                  @"Got %@", r.languages);
}

- (void)testNoCodeBlocksMeansNoLanguages
{
    MPMarkdownResult *r = [self.engine renderMarkdown:@"just text"
                                              options:[self defaultOptions]];
    XCTAssertEqual(r.languages.count, 0u);
}

- (void)testEmptyInput
{
    MPMarkdownResult *r = [self.engine renderMarkdown:@""
                                              options:[self defaultOptions]];
    XCTAssertEqualObjects(r.html, @"");
}

- (void)testFrontMatterIsOnlyRenderedWhenEnabled
{
    NSString *md = @"---\ntitle: T\n---\n\nbody\n";
    MPMarkdownRenderOptions *o = [self defaultOptions];
    NSString *off = [self.engine renderMarkdown:md options:o].html;
    o.detectsFrontMatter = YES;
    NSString *on = [self.engine renderMarkdown:md options:o].html;
    XCTAssertNotEqualObjects(off, on);
    XCTAssertTrue([on containsString:@"<table"], @"Got %@", on);
}

- (void)testLargeDocumentRendersWithoutCrashing
{
    NSMutableString *md = [NSMutableString string];
    for (int i = 0; i < 2000; i++)
        [md appendFormat:@"## Section %d\n\nParagraph *%d* with `code`.\n\n", i, i];
    NSString *html = [self.engine renderMarkdown:md
                                         options:[self defaultOptions]].html;
    XCTAssertTrue([html containsString:@"Section 1999"]);
}

@end
