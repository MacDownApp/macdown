//
//  MPHoedownEngine.m
//  MacDown
//
//  The Hoedown specific code that used to live in MPRenderer.m.
//

#import "MPHoedownEngine.h"
#import <limits.h>
#import <os/signpost.h>
#import <hoedown/html.h>
#import <hoedown/document.h>
#import "hoedown_html_patch.h"
#import "NSJSONSerialization+File.h"
#import "NSObject+HTMLTabularize.h"
#import "NSString+Lookup.h"
#import "MPUtilities.h"

static size_t kMPRendererNestingLevel = SIZE_MAX;
static int kMPRendererTOCLevel = 6;  // h1 to h6.


@implementation MPMarkdownRenderOptions

static NSArray<NSString *> *MPOptionKeys(void)
{
    static NSArray *keys;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        keys = @[@"tables", @"fencedCode", @"footnotes", @"autolink",
                 @"strikethrough", @"underline", @"highlight", @"quote",
                 @"superscript", @"intraEmphasis", @"math",
                 @"mathInlineDollar", @"taskList", @"lineNumbers", @"hardWrap",
                 @"codeBlockInformation", @"smartyPants", @"rendersTOC",
                 @"detectsFrontMatter"];
    });
    return keys;
}

- (id)copyWithZone:(NSZone *)zone
{
    MPMarkdownRenderOptions *copy = [[[self class] allocWithZone:zone] init];
    for (NSString *key in MPOptionKeys())
        [copy setValue:[self valueForKey:key] forKey:key];
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[MPMarkdownRenderOptions class]])
        return NO;
    for (NSString *key in MPOptionKeys())
    {
        if (![[self valueForKey:key] isEqual:[object valueForKey:key]])
            return NO;
    }
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger h = 0;
    for (NSString *key in MPOptionKeys())
        h = h * 31 + [[self valueForKey:key] hash];
    return h;
}

@end


@implementation MPMarkdownResult

- (instancetype)initWithHTML:(NSString *)html
                   languages:(NSArray<NSString *> *)languages
{
    self = [super init];
    if (!self)
        return nil;
    _html = [html copy];
    _languages = [languages copy];
    return self;
}

@end


NS_INLINE NSString *MPHTMLFromMarkdown(
    NSString *text, int flags, BOOL smartypants, NSString *frontMatter,
    hoedown_renderer *htmlRenderer, hoedown_renderer *tocRenderer)
{
    NSData *inputData = [text dataUsingEncoding:NSUTF8StringEncoding];
    hoedown_document *document = hoedown_document_new(
        htmlRenderer, flags, kMPRendererNestingLevel);
    hoedown_buffer *ob = hoedown_buffer_new(64);
    hoedown_document_render(document, ob, inputData.bytes, inputData.length);
    if (smartypants)
    {
        hoedown_buffer *ib = ob;
        ob = hoedown_buffer_new(64);
        hoedown_html_smartypants(ob, ib->data, ib->size);
        hoedown_buffer_free(ib);
    }
    NSString *result = [NSString stringWithUTF8String:hoedown_buffer_cstr(ob)];
    hoedown_document_free(document);
    hoedown_buffer_free(ob);

    if (tocRenderer)
    {
        document = hoedown_document_new(
            tocRenderer, flags, kMPRendererNestingLevel);
        ob = hoedown_buffer_new(64);
        hoedown_document_render(
            document, ob, inputData.bytes, inputData.length);
        NSString *toc = [NSString stringWithUTF8String:hoedown_buffer_cstr(ob)];

        static NSRegularExpression *tocRegex = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *pattern = @"<p.*?>\\s*\\[TOC\\]\\s*</p>";
            NSRegularExpressionOptions ops = NSRegularExpressionCaseInsensitive;
            tocRegex = [[NSRegularExpression alloc] initWithPattern:pattern
                                                            options:ops
                                                              error:NULL];
        });
        NSRange replaceRange = NSMakeRange(0, result.length);
        result = [tocRegex stringByReplacingMatchesInString:result options:0
                                                      range:replaceRange
                                               withTemplate:toc];
        hoedown_document_free(document);
        hoedown_buffer_free(ob);
    }
    if (frontMatter)
        result = [NSString stringWithFormat:@"%@\n%@", frontMatter, result];
    
    return result;
}

NS_INLINE void add_to_languages(
    NSString *lang, NSMutableArray *languages, NSDictionary *languageMap)
{
    // Move language to root of dependencies.
    NSUInteger index = [languages indexOfObject:lang];
    if (index != NSNotFound)
        [languages removeObjectAtIndex:index];
    [languages insertObject:lang atIndex:0];

    // Add dependencies of this language.
    id require = languageMap[lang][@"require"];
    if ([require isKindOfClass:[NSString class]])
    {
        add_to_languages(require, languages, languageMap);
    }
    else if ([require isKindOfClass:[NSArray class]])
    {
        for (NSString *lang in require)
            add_to_languages(lang, languages, languageMap);
    }
    else if (require)
    {
        NSLog(@"Unknown Prism langauge requirement "
              @"%@ dropped for unknown format", require);
    }
}


NS_INLINE hoedown_buffer *language_addition(
    const hoedown_buffer *language, void *owner)
{
    NSMutableArray *languages = (__bridge NSMutableArray *)owner;
    NSString *lang = [[NSString alloc] initWithBytes:language->data
                                              length:language->size
                                            encoding:NSUTF8StringEncoding];

    static NSDictionary *aliasMap = nil;
    static NSDictionary *languageMap = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        NSBundle *bundle = [NSBundle mainBundle];
        NSURL *url = [bundle URLForResource:@"syntax_highlighting"
                              withExtension:@"json"];
        NSDictionary *info =
            [NSJSONSerialization JSONObjectWithFileAtURL:url options:0
                                                   error:NULL];

        aliasMap = info[@"aliases"];

        url = [bundle URLForResource:@"components" withExtension:@"js"
                        subdirectory:@"Prism"];
        NSString *code = [NSString stringWithContentsOfURL:url
                                                  encoding:NSUTF8StringEncoding
                                                     error:NULL];
        NSDictionary *comp = MPGetObjectFromJavaScript(code, @"components");
        languageMap = comp[@"languages"];
    });

    // Try to identify alias and point it to the "real" language name.
    hoedown_buffer *mapped = NULL;
    if ([aliasMap objectForKey:lang])
    {
        lang = [aliasMap objectForKey:lang];
        NSData *data = [lang dataUsingEncoding:NSUTF8StringEncoding];
        mapped = hoedown_buffer_new(64);
        hoedown_buffer_put(mapped, data.bytes, data.length);
    }

    // Walk dependencies to include all required scripts.
    add_to_languages(lang, languages, languageMap);
    
    return mapped;
}

NS_INLINE hoedown_renderer *MPCreateHTMLRenderer(
    int flags, NSMutableArray *languages)
{
    hoedown_renderer *htmlRenderer = hoedown_html_renderer_new(
        flags, kMPRendererTOCLevel);
    htmlRenderer->blockcode = hoedown_patch_render_blockcode;
    htmlRenderer->listitem = hoedown_patch_render_listitem;
    
    hoedown_html_renderer_state_extra *extra =
        hoedown_malloc(sizeof(hoedown_html_renderer_state_extra));
    extra->language_addition = language_addition;
    extra->owner = (__bridge void *)languages;

    ((hoedown_html_renderer_state *)htmlRenderer->opaque)->opaque = extra;
    return htmlRenderer;
}

NS_INLINE hoedown_renderer *MPCreateHTMLTOCRenderer()
{
    hoedown_renderer *tocRenderer =
        hoedown_html_toc_renderer_new(kMPRendererTOCLevel);
    tocRenderer->header = hoedown_patch_render_toc_header;
    return tocRenderer;
}

NS_INLINE void MPFreeHTMLRenderer(hoedown_renderer *htmlRenderer)
{
    hoedown_html_renderer_state_extra *extra =
        ((hoedown_html_renderer_state *)htmlRenderer->opaque)->opaque;
    if (extra)
        free(extra);
    hoedown_html_renderer_free(htmlRenderer);
}




static os_log_t MPHoedownLog(void)
{
    static os_log_t log;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        log = os_log_create("app.macdown", "markdown");
    });
    return log;
}


/// Hoedown parser flags for the given options.
static int MPHoedownExtensions(MPMarkdownRenderOptions *o)
{
    int flags = 0;
    if (o.autolink)
        flags |= HOEDOWN_EXT_AUTOLINK;
    if (o.fencedCode)
        flags |= HOEDOWN_EXT_FENCED_CODE;
    if (o.footnotes)
        flags |= HOEDOWN_EXT_FOOTNOTES;
    if (o.highlight)
        flags |= HOEDOWN_EXT_HIGHLIGHT;
    if (!o.intraEmphasis)
        flags |= HOEDOWN_EXT_NO_INTRA_EMPHASIS;
    if (o.quote)
        flags |= HOEDOWN_EXT_QUOTE;
    if (o.strikethrough)
        flags |= HOEDOWN_EXT_STRIKETHROUGH;
    if (o.superscript)
        flags |= HOEDOWN_EXT_SUPERSCRIPT;
    if (o.tables)
        flags |= HOEDOWN_EXT_TABLES;
    if (o.underline)
        flags |= HOEDOWN_EXT_UNDERLINE;
    if (o.math)
        flags |= HOEDOWN_EXT_MATH;
    if (o.mathInlineDollar)
        flags |= HOEDOWN_EXT_MATH_EXPLICIT;
    return flags;
}

static int MPHoedownRendererFlags(MPMarkdownRenderOptions *o)
{
    int flags = 0;
    if (o.taskList)
        flags |= HOEDOWN_HTML_USE_TASK_LIST;
    if (o.lineNumbers)
        flags |= HOEDOWN_HTML_BLOCKCODE_LINE_NUMBERS;
    if (o.hardWrap)
        flags |= HOEDOWN_HTML_HARD_WRAP;
    if (o.codeBlockInformation)
        flags |= HOEDOWN_HTML_BLOCKCODE_INFORMATION;
    return flags;
}


@implementation MPHoedownEngine

- (MPMarkdownResult *)renderMarkdown:(NSString *)markdown
                             options:(MPMarkdownRenderOptions *)options
{
    os_signpost_id_t signpost = os_signpost_id_generate(MPHoedownLog());
    os_signpost_interval_begin(MPHoedownLog(), signpost, "render");

    NSMutableArray *languages = [NSMutableArray array];

    id frontMatter = nil;
    if (options.detectsFrontMatter)
    {
        NSUInteger offset = 0;
        frontMatter = [markdown frontMatter:&offset];
        markdown = [markdown substringFromIndex:offset];
    }

    hoedown_renderer *htmlRenderer =
        MPCreateHTMLRenderer(MPHoedownRendererFlags(options), languages);
    hoedown_renderer *tocRenderer = NULL;
    if (options.rendersTOC)
        tocRenderer = MPCreateHTMLTOCRenderer();

    NSString *html = MPHTMLFromMarkdown(
        markdown, MPHoedownExtensions(options), options.smartyPants,
        [frontMatter HTMLTable], htmlRenderer, tocRenderer);

    if (tocRenderer)
        hoedown_html_renderer_free(tocRenderer);
    MPFreeHTMLRenderer(htmlRenderer);

    os_signpost_interval_end(MPHoedownLog(), signpost, "render");
    return [[MPMarkdownResult alloc] initWithHTML:html languages:languages];
}

@end
