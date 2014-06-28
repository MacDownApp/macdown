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
#import "hoedown_html_patch.h"
#import "MPUtilities.h"

typedef NS_ENUM(NSInteger, MPAssetsOption)
{
    MPAssetsNone,
    MPAssetsEmbedded,
    MPAssetsFullLink,
};

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

static NSString *MPHTMLFromMarkdown(NSString *text, int flags, BOOL smartypants,
                                    hoedown_renderer *renderer)
{
    NSData *inputData = [text dataUsingEncoding:NSUTF8StringEncoding];
    hoedown_markdown *markdown = hoedown_markdown_new(flags, 15, renderer);
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
    return result;
}

static NSString *MPGetHTML(
    NSString *title, NSString *body, NSArray *stylesrc, MPAssetsOption styleopt,
    NSArray *scriptsrc, MPAssetsOption scriptopt)
{
    NSString *format;

    // Styles.
    NSMutableArray *styles = [NSMutableArray array];
    for (NSURL *url in stylesrc)
    {
        NSString *s = nil;
        if (!url.isFileURL)
            styleopt = MPAssetsFullLink;
        switch (styleopt)
        {
            case MPAssetsFullLink:
                format =
                    @"<link rel=\"stylesheet\" type=\"text/css\" href=\"%@\">";
                s = [NSString stringWithFormat:format, url.absoluteString];
                break;
            case MPAssetsEmbedded:
                s = [NSString stringWithFormat:@"<style>\n%@\n</style>",
                                               MPReadFileOfPath(url.path)];
                break;
            default:
                break;
        }
        if (s)
            [styles addObject:s];
    }
    NSString *style = [styles componentsJoinedByString:@"\n"];

    // Scripts.
    NSMutableArray *scripts = [NSMutableArray array];
    for (NSURL *url in scriptsrc)
    {
        NSString *s = nil;
        if (!url.isFileURL)
            scriptopt = MPAssetsFullLink;
        switch (scriptopt)
        {
            case MPAssetsFullLink:
                format =
                    @"<script type=\"text/javascript\" src=\"%@\"></script>";
                s = [NSString stringWithFormat:format, url.absoluteString];
                break;
            case MPAssetsEmbedded:
                format = @"<script type=\"text/javascript\">%@</script>";
                s = [NSString stringWithFormat:format,
                                               MPReadFileOfPath(url.path)];
                break;
            default:
                break;
        }
        if (s)
            [scripts addObject:s];
    }
    NSString *script = [scripts componentsJoinedByString:@"\n"];

    static NSString *f =
        (@"<!DOCTYPE html><html>\n\n"
         @"<head>\n<meta charset=\"utf-8\">\n%@%@\n</head>"
         @"<body>\n%@\n%@\n</body>\n\n</html>\n");

    if (title.length)
        title = [NSString stringWithFormat:@"<title>%@</title>\n", title];
    else
        title = @"";
    NSString *html = [NSString stringWithFormat:f, title, style, body, script];
    return html;
}


@interface MPRenderer ()

@property (nonatomic, unsafe_unretained) hoedown_renderer *htmlRenderer;
@property (strong) NSMutableArray *currentLanguages;
@property (readonly) NSArray *prismStylesheets;
@property (readonly) NSArray *prismScripts;
@property (readonly) NSArray *stylesheets;
@property (readonly) NSArray *scripts;
@property (copy) NSString *currentHtml;
@property (strong) NSTimer *parseDelayTimer;
@property int extensions;
@property BOOL smartypants;
@property NSString *styleName;
@property BOOL mathjax;
@property BOOL syntaxHighlighting;
@property BOOL manualRender;
@property NSString *highlightingThemeName;

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
        aliasMap = @{@"objective-c": @"objectivec",
                     @"obj-c": @"objectivec", @"objc": @"objectivec",
                     @"html": @"markup", @"xml": @"markup"};
        dependencyMap = @{
            @"aspnet": @"markup", @"bash": @"clike", @"c": @"clike",
            @"coffeescript": @"javascript", @"cpp": @"c", @"csharp": @"clike",
            @"go": @"clike", @"groovy": @"clike", @"java": @"clike",
            @"javascript": @"clike", @"objectivec": @"c", @"php": @"clike",
            @"ruby": @"clike", @"scala": @"java", @"scss": @"css",
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
    self.htmlRenderer = hoedown_html_renderer_new(0, 0);

    return self;
}

- (void)dealloc
{
    self.htmlRenderer = NULL;
}


#pragma mark - Accessor

- (void)setHtmlRenderer:(hoedown_renderer *)htmlRenderer
{
    if (_htmlRenderer)
        hoedown_html_renderer_free(_htmlRenderer);

    _htmlRenderer = htmlRenderer;

    if (_htmlRenderer)
    {
        _htmlRenderer->blockcode = hoedown_patch_render_blockcode;

        rndr_state_ex *state = malloc(sizeof(rndr_state_ex));
        memcpy(state, _htmlRenderer->opaque, sizeof(rndr_state));
        state->language_addition = language_addition;
        state->owner = (__bridge void *)self;

        free(_htmlRenderer->opaque);
        _htmlRenderer->opaque = state;
    }
}

- (NSArray *)prismStylesheets
{
    NSString *name = [self.delegate rendererHighlightingThemeName:self];
    return @[MPHighlightingThemeURLForName(name)];
}

- (NSArray *)prismScripts
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSMutableArray *urls = [NSMutableArray array];
    [urls addObject:[bundle URLForResource:@"prism-core.min" withExtension:@"js"
                              subdirectory:kMPPrismScriptDirectory]];
    for (NSString *language in self.currentLanguages)
        [urls addObjectsFromArray:MPPrismScriptURLsForLanguage(language)];
    return urls;
}

- (NSArray *)stylesheets
{
    id<MPRendererDelegate> d = self.delegate;
    NSString *defaultStyle = MPStylePathForName([d rendererStyleName:self]);
    NSMutableArray *urls =
        [NSMutableArray arrayWithObject:[NSURL fileURLWithPath:defaultStyle]];
    if ([d rendererHasSyntaxHighlighting:self])
        [urls addObjectsFromArray:self.prismStylesheets];
    return urls;
}

- (NSArray *)scripts
{
    id<MPRendererDelegate> d = self.delegate;
    NSMutableArray *urls = [NSMutableArray array];
    if ([d rendererHasSyntaxHighlighting:self])
        [urls addObjectsFromArray:self.prismScripts];
    if ([d rendererHasMathJax:self])
        [urls addObject:[NSURL URLWithString:kMPMathJaxCDN]];
    return urls;
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
    if ([self.delegate rendererExtensions:self] != self.extensions
            || [self.delegate rendererHasSmartyPants:self] != self.smartypants)
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
    NSString *markdown = [self.dataSource rendererMarkdown:self];
    self.currentHtml = MPHTMLFromMarkdown(
        markdown, extensions, smartypants, self.htmlRenderer);

    self.extensions = extensions;
    self.smartypants = smartypants;

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
        title, self.currentHtml, self.stylesheets, MPAssetsFullLink,
        self.scripts, MPAssetsFullLink);
    [delegate renderer:self didProduceHTMLOutput:html];

    self.styleName = [delegate rendererStyleName:self];
    self.mathjax = [delegate rendererHasMathJax:self];
    self.syntaxHighlighting = [delegate rendererHasSyntaxHighlighting:self];
    self.highlightingThemeName = [delegate rendererHighlightingThemeName:self];
}

- (NSString *)HTMLForExportWithStyles:(BOOL)withStyles
                         highlighting:(BOOL)withHighlighting
{
    MPAssetsOption stylesOption = MPAssetsNone;
    MPAssetsOption scriptsOption = MPAssetsNone;
    NSMutableArray *styles = [NSMutableArray array];
    NSMutableArray *scripts = [NSMutableArray array];

    if (withStyles)
    {
        stylesOption = MPAssetsEmbedded;
        NSString *path = MPStylePathForName(self.styleName);
        [styles addObject:[NSURL fileURLWithPath:path]];
    }
    if (withHighlighting)
    {
        stylesOption = MPAssetsEmbedded;
        scriptsOption = MPAssetsEmbedded;
        [styles addObjectsFromArray:self.prismStylesheets];
        [scripts addObjectsFromArray:self.prismScripts];
    }
    if ([self.delegate rendererHasMathJax:self])
    {
        scriptsOption = MPAssetsEmbedded;
        [scripts addObject:[NSURL URLWithString:kMPMathJaxCDN]];
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
