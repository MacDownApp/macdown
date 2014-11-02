//
//  MPRenderer.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 26/6.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPRenderer.h"
#import <limits.h>
#import "html.h"
#import "document.h"
#import "hoedown_html_patch.h"
#import "NSObject+HTMLTabularize.h"
#import "NSString+Lookup.h"
#import "MPUtilities.h"
#import "MPAsset.h"


static NSString * const kMPKateXScriptDirectory = @"katex";
static NSString * const kMPKatexStylesheetDirectory = @"katex";
static NSString * const kMPPrismScriptDirectory = @"prism/components";
static NSString * const kMPPrismThemeDirectory = @"prism/themes";
static size_t kMPRendererNestingLevel = SIZE_MAX;
static int kMPRendererTOCLevel = 6;  // h1 to h6.


static NSArray *MPPrismScriptURLsForLanguage(NSString *language)
{
    NSURL *baseUrl = nil;
    NSURL *extraUrl = nil;
    NSBundle *bundle = [NSBundle mainBundle];

    language = [language lowercaseString];
    NSString *baseFileName =
        [NSString stringWithFormat:@"prism-%@", language];
    NSString *extraFileName =
        [NSString stringWithFormat:@"prism-%@-extras", language];

    for (NSString *ext in @[@"min.js", @"js"])
    {
        if (!baseUrl)
        {
            baseUrl = [bundle URLForResource:baseFileName withExtension:ext
                                subdirectory:kMPPrismScriptDirectory];
        }
        if (!extraUrl)
        {
            extraUrl = [bundle URLForResource:extraFileName withExtension:ext
                                 subdirectory:kMPPrismScriptDirectory];
        }
    }

    NSMutableArray *urls = [NSMutableArray array];
    if (baseUrl)
        [urls addObject:baseUrl];
    if (extraUrl)
        [urls addObject:extraUrl];
    return urls;
}

static NSString *MPHTMLFromMarkdown(
    NSString *text, int flags, BOOL smartypants, NSString *frontMatter,
    hoedown_renderer *htmlRenderer, hoedown_renderer *tocRenderer)
{
    NSData *inputData = [text dataUsingEncoding:NSUTF8StringEncoding];
    hoedown_document *markdown = hoedown_document_new(
        htmlRenderer, flags, kMPRendererNestingLevel);
    hoedown_buffer *ob = hoedown_buffer_new(64);
    hoedown_document_render(markdown, ob, inputData.bytes, inputData.length);
    if (smartypants)
    {
        hoedown_buffer *ib = ob;
        ob = hoedown_buffer_new(64);
        hoedown_html_smartypants(ob, ib->data, ib->size);
        hoedown_buffer_free(ib);
    }
    NSString *result = [NSString stringWithUTF8String:hoedown_buffer_cstr(ob)];
    hoedown_document_free(markdown);
    hoedown_buffer_free(ob);

    if (tocRenderer)
    {
        markdown = hoedown_document_new(tocRenderer, flags,
            kMPRendererNestingLevel);
        ob = hoedown_buffer_new(64);
        hoedown_document_render(
            markdown, ob, inputData.bytes, inputData.length);
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
        hoedown_document_free(markdown);
        hoedown_buffer_free(ob);
    }
    if (frontMatter)
        result = [NSString stringWithFormat:@"%@\n%@", frontMatter, result];
    
    return result;
}

static NSString *MPGetHTML(
    NSString *title, NSString *body, NSArray *styles, MPAssetOption styleopt,
    NSArray *scripts, MPAssetOption scriptopt)
{
    NSMutableArray *styleTags = [NSMutableArray array];
    NSMutableArray *scriptTags = [NSMutableArray array];
    for (MPStyleSheet *style in styles)
    {
        NSString *s = [style htmlForOption:styleopt];
        if (s)
            [styleTags addObject:s];
    }
    for (MPScript *script in scripts)
    {
        NSString *s = [script htmlForOption:scriptopt];
        if (s)
            [scriptTags addObject:s];
    }
    NSString *style = [styleTags componentsJoinedByString:@"\n"];
    NSString *script = [scriptTags componentsJoinedByString:@"\n"];

    static NSString *f =
        (@"<!DOCTYPE html><html>\n\n"
         @"<head>\n<meta charset=\"utf-8\">\n%@%@\n</head>\n"
         @"<body>\n%@\n%@\n</body>\n\n</html>\n");

    if (title.length)
        title = [NSString stringWithFormat:@"<title>%@</title>\n", title];
    else
        title = @"";
    NSString *html = [NSString stringWithFormat:f, title, style, body, script];
    return html;
}

static inline BOOL MPAreNilableStringsEqual(NSString *s1, NSString *s2)
{
    // The == part takes care of cases where s1 and s2 are both nil.
    return ([s1 isEqualToString:s2] || s1 == s2);
}


@interface MPRenderer ()

@property (strong) NSMutableArray *currentLanguages;
@property (readonly) NSArray *baseStylesheets;
@property (readonly) NSArray *prismStylesheets;
@property (readonly) NSArray *prismScripts;
@property (readonly) NSArray *katexScripts;
@property (readonly) NSArray *stylesheets;
@property (readonly) NSArray *scripts;
@property (copy) NSString *currentHtml;
@property (strong) NSTimer *parseDelayTimer;
@property int extensions;
@property BOOL smartypants;
@property BOOL TOC;
@property (copy) NSString *styleName;
@property BOOL frontMatter;
@property BOOL katex;
@property BOOL syntaxHighlighting;
@property BOOL manualRender;
@property (copy) NSString *highlightingThemeName;

@end


static hoedown_buffer *language_addition(const hoedown_buffer *language,
                                         void *owner)
{
    MPRenderer *renderer = (__bridge MPRenderer *)owner;
    NSString *lang = [[NSString alloc] initWithBytes:language->data
                                              length:language->size
                                            encoding:NSUTF8StringEncoding];

    static NSDictionary *aliasMap = nil;
    static NSDictionary *languageMap = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        aliasMap = @{
            @"c++": @"cpp",
            @"coffee": @"coffeescript",
            @"coffee-script": @"coffeescript",
            @"cs": @"csharp",
            @"html": @"markup",
            @"js": @"javascript",
            @"json": @"javascript",
            @"objective-c": @"objectivec",
            @"obj-c": @"objectivec",
            @"objc": @"objectivec",
            @"py": @"python",
            @"rb": @"ruby",
            @"sh": @"bash",
            @"xml": @"markup",
        };

        NSBundle *bundle = [NSBundle mainBundle];
        NSURL *url = [bundle URLForResource:@"components" withExtension:@"js"
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
    NSMutableArray *languages = renderer.currentLanguages;
    while (lang)
    {
        NSUInteger index = [languages indexOfObject:lang];
        if (index != NSNotFound)
            [languages removeObjectAtIndex:index];
        [languages insertObject:lang atIndex:0];
        lang = languageMap[lang][@"require"];
    }
    
    return mapped;
}

static hoedown_renderer *MPCreateHTMLRenderer(MPRenderer *renderer)
{
    int flags = renderer.rendererFlags;
    hoedown_renderer *htmlRenderer = hoedown_html_renderer_new(
        flags, kMPRendererTOCLevel);
    htmlRenderer->blockcode = hoedown_patch_render_blockcode;
    htmlRenderer->listitem = hoedown_patch_render_listitem;
    htmlRenderer->math = hoedown_patch_render_math;

    rndr_state_ex *state = malloc(sizeof(rndr_state_ex));
    memcpy(state, htmlRenderer->opaque, sizeof(rndr_state));
    state->language_addition = language_addition;
    state->owner = (__bridge void *)renderer;

    free(htmlRenderer->opaque);
    htmlRenderer->opaque = state;
    return htmlRenderer;
}


@implementation MPRenderer

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    self.currentHtml = @"";
    self.currentLanguages = [NSMutableArray array];

    return self;
}

#pragma mark - Accessor

- (NSArray *)baseStylesheets
{
    NSString *defaultStyleName =
        MPStylePathForName([self.delegate rendererStyleName:self]);
    if (!defaultStyleName)
        return @[];
    NSURL *defaultStyle = [NSURL fileURLWithPath:defaultStyleName];
    NSMutableArray *stylesheets = [NSMutableArray array];
    [stylesheets addObject:[MPStyleSheet CSSWithURL:defaultStyle]];
    return stylesheets;
}

- (NSArray *)prismStylesheets
{
    NSString *name = [self.delegate rendererHighlightingThemeName:self];
    return @[[MPStyleSheet CSSWithURL:MPHighlightingThemeURLForName(name)]];
}

- (NSArray *)prismScripts
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *url = [bundle URLForResource:@"prism-core.min" withExtension:@"js"
                           subdirectory:kMPPrismScriptDirectory];
    MPAsset *script = [MPScript javaScriptWithURL:url];
    NSMutableArray *scripts = [NSMutableArray arrayWithObject:script];
    for (NSString *language in self.currentLanguages)
    {
        for (NSURL *url in MPPrismScriptURLsForLanguage(language))
            [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    return scripts;
}

- (NSArray *)katexScripts
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *url1 = [bundle URLForResource:@"katex.min"
                          withExtension:@"js"
                          subdirectory:kMPKateXScriptDirectory];
    NSURL *url2 = [bundle URLForResource:@"watchkatex"
                          withExtension:@"js"];
    NSArray *scripts = @[
        [MPScript javaScriptWithURL:url1],
        [MPScript javaScriptWithURL:url2]
    ];
    return scripts;
}

- (NSArray *)stylesheets
{
    NSMutableArray *stylesheets = [self.baseStylesheets mutableCopy];
    if ([self.delegate rendererHasSyntaxHighlighting:self])
        [stylesheets addObjectsFromArray:self.prismStylesheets];
    if ([self.delegate rendererHasKatex:self]) {
        NSBundle *bundle = [NSBundle mainBundle];
        NSURL *url = [bundle URLForResource:@"katex.min"
                             withExtension:@"css"
                             subdirectory:kMPKatexStylesheetDirectory];
        [stylesheets addObject:[MPStyleSheet CSSWithURL:url]];
    }
    return stylesheets;
}

- (NSArray *)scripts
{
    id<MPRendererDelegate> d = self.delegate;
    NSMutableArray *scripts = [NSMutableArray array];
    if (self.rendererFlags & HOEDOWN_HTML_USE_TASK_LIST)
    {
        NSBundle *bundle = [NSBundle mainBundle];
        NSURL *url = [bundle URLForResource:@"tasklist" withExtension:@"js"
                               subdirectory:@"Extensions"];
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    if ([d rendererHasSyntaxHighlighting:self])
        [scripts addObjectsFromArray:self.prismScripts];
    if ([d rendererHasKatex:self])
        [scripts addObjectsFromArray:self.katexScripts];
    return scripts;
}

#pragma mark - Public

- (void)parseAndRenderNow
{
    [self parseNowWithCommand:@selector(parse) completionHandler:^{
        [self render];
    }];
}

- (void)parseAndRenderLater
{
    [self parseLaterWithCommand:@selector(parse) completionHandler:^{
        [self render];
    }];
}

- (void)parseNowWithCommand:(SEL)action completionHandler:(void(^)())handler
{
    [self parseLater:0.0 withCommand:action completionHandler:handler];
}

- (void)parseLaterWithCommand:(SEL)action completionHandler:(void(^)())handler
{
    [self parseLater:0.5 withCommand:action completionHandler:handler];
}

- (void)parseIfPreferencesChanged
{
    id<MPRendererDelegate> delegate = self.delegate;
    if ([delegate rendererExtensions:self] != self.extensions
            || [delegate rendererHasSmartyPants:self] != self.smartypants
            || [delegate rendererRendersTOC:self] != self.TOC
            || [delegate rendererDetectsFrontMatter:self] != self.frontMatter)
        [self parse];
}

- (void)parse
{
    void(^nextAction)() = nil;
    if (self.parseDelayTimer.isValid)
    {
        nextAction = self.parseDelayTimer.userInfo[@"next"];
        [self.parseDelayTimer invalidate];
    }

    [self.currentLanguages removeAllObjects];

    id<MPRendererDelegate> delegate = self.delegate;
    int extensions = [delegate rendererExtensions:self];
    BOOL smartypants = [delegate rendererHasSmartyPants:self];
    BOOL hasFrontMatter = [delegate rendererDetectsFrontMatter:self];
    BOOL hasTOC = [delegate rendererRendersTOC:self];

    id frontMatter = nil;
    NSString *markdown = [self.dataSource rendererMarkdown:self];
    if (hasFrontMatter)
    {
        NSUInteger offset = 0;
        frontMatter = [markdown frontMatter:&offset];
        markdown = [markdown substringFromIndex:offset];
    }
    hoedown_renderer *htmlRenderer = MPCreateHTMLRenderer(self);
    hoedown_renderer *tocRenderer = NULL;
    if (hasTOC)
        tocRenderer = hoedown_html_toc_renderer_new(kMPRendererTOCLevel);
    self.currentHtml = MPHTMLFromMarkdown(
        markdown, extensions, smartypants, [frontMatter HTMLTable],
        htmlRenderer, tocRenderer);
    if (tocRenderer)
        hoedown_html_renderer_free(tocRenderer);
    hoedown_html_renderer_free(htmlRenderer);

    self.extensions = extensions;
    self.smartypants = smartypants;
    self.TOC = hasTOC;
    self.frontMatter = hasFrontMatter;

    if (nextAction)
        nextAction();
}

- (void)renderIfPreferencesChanged
{
    BOOL changed = NO;
    id<MPRendererDelegate> d = self.delegate;
    if ([d rendererHasSyntaxHighlighting:self] != self.syntaxHighlighting)
        changed = YES;
    else if ([d rendererHasKatex:self] != self.katex)
        changed = YES;
    else if (!MPAreNilableStringsEqual(
            [d rendererHighlightingThemeName:self], self.highlightingThemeName))
        changed = YES;
    else if (!MPAreNilableStringsEqual(
            [d rendererStyleName:self], self.styleName))
        changed = YES;

    if (changed)
        [self render];
}

- (void)render
{
    id<MPRendererDelegate> delegate = self.delegate;

    NSString *title = [self.dataSource rendererHTMLTitle:self];
    NSString *html = MPGetHTML(
        title, self.currentHtml, self.stylesheets, MPAssetFullLink,
        self.scripts, MPAssetFullLink);
    [delegate renderer:self didProduceHTMLOutput:html];

    self.styleName = [delegate rendererStyleName:self];
    self.katex = [delegate rendererHasKatex:self];
    self.syntaxHighlighting = [delegate rendererHasSyntaxHighlighting:self];
    self.highlightingThemeName = [delegate rendererHighlightingThemeName:self];
}

- (NSString *)HTMLForExportWithStyles:(BOOL)withStyles
                         highlighting:(BOOL)withHighlighting
{
    MPAssetOption stylesOption = MPAssetNone;
    MPAssetOption scriptsOption = MPAssetNone;
    NSMutableArray *styles = [NSMutableArray array];
    NSMutableArray *scripts = [NSMutableArray array];

    if (withStyles)
    {
        stylesOption = MPAssetEmbedded;
        [styles addObjectsFromArray:self.baseStylesheets];
    }
    if (withHighlighting)
    {
        stylesOption = MPAssetEmbedded;
        scriptsOption = MPAssetEmbedded;
        [styles addObjectsFromArray:self.prismStylesheets];
        [scripts addObjectsFromArray:self.prismScripts];
    }
    if ([self.delegate rendererHasKatex:self])
    {
        scriptsOption = MPAssetEmbedded;
        [scripts addObjectsFromArray:self.katexScripts];
    }

    NSString *title = [self.dataSource rendererHTMLTitle:self];
    if (!title)
        title = @"";
    NSString *html = MPGetHTML(
        title, self.currentHtml, styles, stylesOption, scripts, scriptsOption);
    return html;
}


#pragma mark - Private

- (void)parseLater:(NSTimeInterval)delay
       withCommand:(SEL)action completionHandler:(void(^)())handler
{
    self.parseDelayTimer =
        [NSTimer scheduledTimerWithTimeInterval:delay
                                         target:self
                                       selector:action
                                       userInfo:@{@"next": handler}
                                        repeats:NO];
}

@end
