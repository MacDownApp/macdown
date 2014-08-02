//
//  MPRenderer.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 26/6.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPRenderer.h"
#import <hoedown/html.h>
#import <hoedown/markdown.h>
#import "YAMLSerialization.h"
#import "hoedown_html_patch.h"
#import "NSObject+HTMLTabularize.h"
#import "MPUtilities.h"
#import "MPAsset.h"


static NSString * const kMPMathJaxCDN =
    @"http://cdn.mathjax.org/mathjax/latest/MathJax.js"
    @"?config=TeX-AMS-MML_HTMLorMML";
static NSString * const kMPPrismScriptDirectory = @"Prism/components";
static NSString * const kMPPrismThemeDirectory = @"Prism/themes";


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
    hoedown_markdown *markdown = hoedown_markdown_new(flags, 15, htmlRenderer);
    hoedown_buffer *ob = hoedown_buffer_new(64);
    hoedown_markdown_render(ob, inputData.bytes, inputData.length, markdown);
    if (smartypants)
    {
        hoedown_buffer *ib = ob;
        ob = hoedown_buffer_new(64);
        hoedown_html_smartypants(ob, ib->data, ib->size);
        hoedown_buffer_free(ib);
    }
    NSString *result = [NSString stringWithUTF8String:hoedown_buffer_cstr(ob)];
    hoedown_markdown_free(markdown);
    hoedown_buffer_free(ob);

    if (tocRenderer)
    {
        markdown = hoedown_markdown_new(flags, 15, tocRenderer);
        ob = hoedown_buffer_new(64);
        hoedown_markdown_render(
            ob, inputData.bytes, inputData.length, markdown);
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
        hoedown_markdown_free(markdown);
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


@interface MPRenderer ()

@property (nonatomic, unsafe_unretained) hoedown_renderer *tocRenderer;
@property (nonatomic, unsafe_unretained) hoedown_renderer *htmlRenderer;
@property (strong) NSMutableArray *currentLanguages;
@property (readonly) NSArray *baseStylesheets;
@property (readonly) NSArray *prismStylesheets;
@property (readonly) NSArray *prismScripts;
@property (readonly) NSArray *mathjaxScripts;
@property (readonly) NSArray *stylesheets;
@property (readonly) NSArray *scripts;
@property (copy) NSString *currentHtml;
@property (strong) NSTimer *parseDelayTimer;
@property int extensions;
@property BOOL smartypants;
@property BOOL TOC;
@property (copy) NSString *styleName;
@property BOOL frontMatter;
@property BOOL mathjax;
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
    static NSDictionary *dependencyMap = nil;
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
        dependencyMap = @{
            @"aspnet": @"markup",
            @"bash": @"clike",
            @"c": @"clike",
            @"coffeescript": @"javascript",
            @"cpp": @"c",
            @"csharp": @"clike",
            @"go": @"clike",
            @"groovy": @"clike",
            @"java": @"clike",
            @"javascript": @"clike",
            @"objectivec": @"c",
            @"php": @"clike",
            @"ruby": @"clike",
            @"scala": @"java",
            @"scss": @"css",
            @"swift": @"clike",
        };
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
        lang = dependencyMap[lang];
    }
    
    return mapped;
}


@implementation MPRenderer

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    self.currentHtml = @"";
    self.currentLanguages = [NSMutableArray array];
    self.tocRenderer = hoedown_html_toc_renderer_new(6);
    self.htmlRenderer = hoedown_html_renderer_new(0, 6);

    return self;
}

- (void)dealloc
{
    self.tocRenderer = NULL;
    self.htmlRenderer = NULL;
}


#pragma mark - Accessor

- (void)setRendererFlags:(int)rendererFlags
{
    if (rendererFlags == _rendererFlags)
        return;

    _rendererFlags = rendererFlags;
    rndr_state_ex *state = self.htmlRenderer->opaque;
    state->flags = rendererFlags;
}

- (void)setTocRenderer:(hoedown_renderer *)tocRenderer
{
    if (_tocRenderer)
        hoedown_html_renderer_free(_tocRenderer);
    _tocRenderer = tocRenderer;
}

- (void)setHtmlRenderer:(hoedown_renderer *)htmlRenderer
{
    if (_htmlRenderer)
        hoedown_html_renderer_free(_htmlRenderer);

    _htmlRenderer = htmlRenderer;

    if (_htmlRenderer)
    {
        _htmlRenderer->blockcode = hoedown_patch_render_blockcode;
        _htmlRenderer->listitem = hoedown_patch_render_listitem;

        rndr_state_ex *state = malloc(sizeof(rndr_state_ex));
        memcpy(state, _htmlRenderer->opaque, sizeof(rndr_state));
        state->language_addition = language_addition;
        state->owner = (__bridge void *)self;

        free(_htmlRenderer->opaque);
        _htmlRenderer->opaque = state;
    }
}

- (NSArray *)baseStylesheets
{
    NSString *defaultStyleName =
        MPStylePathForName([self.delegate rendererStyleName:self]);
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

- (NSArray *)mathjaxScripts
{
    NSMutableArray *scripts = [NSMutableArray array];
    NSURL *url = [NSURL URLWithString:kMPMathJaxCDN];
    if ([self.delegate rendererMathJaxInlineDollarEnabled:self])
    {
        NSBundle *b = [NSBundle mainBundle];
        MPEmbeddedScript *script =
            [MPEmbeddedScript assetWithURL:[b URLForResource:@"inline"
                                               withExtension:@"js"
                                                subdirectory:@"MathJax"]
                                   andType:kMPMathJaxConfigType];
        [scripts addObject:script];
    }
    [scripts addObject:[MPScript javaScriptWithURL:url]];
    return scripts;
}

- (NSArray *)stylesheets
{
    NSMutableArray *stylesheets = [self.baseStylesheets mutableCopy];
    if ([self.delegate rendererHasSyntaxHighlighting:self])
        [stylesheets addObjectsFromArray:self.prismStylesheets];
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
    if ([d rendererHasMathJax:self])
        [scripts addObjectsFromArray:self.mathjaxScripts];
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

    NSString *frontMatter = nil;
    NSString *markdown = [self.dataSource rendererMarkdown:self];
    if (hasFrontMatter)
    {
        NSRange restRange = NSMakeRange(0, markdown.length);
        frontMatter = [self frontMatterFromMarkdown:markdown
                                                    restRange:&restRange];
        if (frontMatter.length)
            markdown = [markdown substringWithRange:restRange];
    }
    hoedown_renderer *tocRenderer = NULL;
    if (hasTOC)
        tocRenderer = self.tocRenderer;
    self.currentHtml = MPHTMLFromMarkdown(
        markdown, extensions, smartypants, frontMatter, self.htmlRenderer,
        tocRenderer);

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
    else if ([d rendererHasMathJax:self] != self.mathjax)
        changed = YES;
    else if (![[d rendererHighlightingThemeName:self]
                   isEqualToString:self.highlightingThemeName])
        changed = YES;
    else if (![[d rendererStyleName:self] isEqualToString:self.styleName])
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
    self.mathjax = [delegate rendererHasMathJax:self];
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
    if ([self.delegate rendererHasMathJax:self])
    {
        scriptsOption = MPAssetEmbedded;
        [scripts addObjectsFromArray:self.mathjaxScripts];
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

- (NSString *)frontMatterFromMarkdown:(NSString *)input
                            restRange:(out NSRange *)restRange
{
    NSRegularExpressionOptions op = NSRegularExpressionDotMatchesLineSeparators;
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:@"^---\n(.*?\n)---"
                                                  options:op error:NULL];
    NSTextCheckingResult *result =
        [regex firstMatchInString:input options:0
                            range:NSMakeRange(0, input.length)];
    if (!result)    // No front matter match. Do nothing.
    {
        if (restRange)
            *restRange = NSMakeRange(0, input.length);
        return nil;
    }

    NSRange frontMatterRange = [result rangeAtIndex:1];
    NSUInteger restStart = frontMatterRange.length + 7;

    NSString *frontMatter = [input substringWithRange:frontMatterRange];
    NSArray *objects =
        [YAMLSerialization objectsWithYAMLString:frontMatter
                                         options:kYAMLReadOptionStringScalars
                                           error:NULL];
    if (!objects.count)
    {
        if (restRange)
            *restRange = NSMakeRange(0, input.length);
        return nil;
    }
    NSString *table = [objects[0] HTMLTable];
    if (restRange)
        *restRange = NSMakeRange(restStart, input.length - restStart);
    return table;
}

@end
