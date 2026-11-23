//
//  MPRenderer.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 26/6.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPRenderer.h"
#import <HBHandlebars/HBHandlebars.h>
#import "NSJSONSerialization+File.h"
#import "MPUtilities.h"
#import "MPAsset.h"
#import "MPPreferences.h"
#import "MacDown-Swift.h"

// Warning: If the version of MathJax is ever updated, please check the status
// of https://github.com/mathjax/MathJax/issues/548. If the fix has been merged
// in to MathJax, then the WebResourceLoadDelegate can be removed from MPDocument
// and MathJax.js can be removed from this project.
static NSString * const kMPMathJaxCDN =
    @"https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.3/MathJax.js"
    @"?config=TeX-AMS-MML_HTMLorMML";
static NSString * const kMPPrismScriptDirectory = @"Prism/components";
static NSString * const kMPPrismThemeDirectory = @"Prism/themes";
static NSString * const kMPPrismPluginDirectory = @"Prism/plugins";


NS_INLINE NSURL *MPExtensionURL(NSString *name, NSString *extension)
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *url = [bundle URLForResource:name withExtension:extension
                           subdirectory:@"Extensions"];
    return url;
}

NS_INLINE NSURL *MPPrismPluginURL(NSString *name, NSString *extension)
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *dirPath =
        [NSString stringWithFormat:@"%@/%@", kMPPrismPluginDirectory, name];

    NSString *filename = [NSString stringWithFormat:@"prism-%@.min", name];
    NSURL *url = [bundle URLForResource:filename withExtension:extension
                           subdirectory:dirPath];
    if (url)
        return url;

    filename = [NSString stringWithFormat:@"prism-%@", name];
    url = [bundle URLForResource:filename withExtension:extension
                    subdirectory:dirPath];
    return url;
}

NS_INLINE NSArray *MPPrismScriptURLsForLanguage(NSString *language)
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

NS_INLINE NSString *MPGetHTML(
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

    MPPreferences *preferences = [MPPreferences sharedInstance];

    static NSString *f = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        NSBundle *bundle = [NSBundle mainBundle];
        NSURL *url = [bundle URLForResource:preferences.htmlTemplateName
                              withExtension:@".handlebars"
                               subdirectory:@"Templates"];
        f = [NSString stringWithContentsOfURL:url
                                     encoding:NSUTF8StringEncoding error:NULL];
    });
    NSCAssert(f.length, @"Could not read template");

    NSString *titleTag = @"";
    if (title.length)
        titleTag = [NSString stringWithFormat:@"<title>%@</title>", title];

    NSDictionary *context = @{
        @"title": title ? title : @"",
        @"titleTag": titleTag ? titleTag : @"",
        @"styleTags": styleTags ? styleTags : @[],
        @"body": body ? body : @"",
        @"scriptTags": scriptTags ? scriptTags : @[],
    };
    NSString *html = [HBHandlebars renderTemplateString:f withContext:context
                                                  error:NULL];
    return html;
}

NS_INLINE BOOL MPAreNilableStringsEqual(NSString *s1, NSString *s2)
{
    // The == part takes care of cases where s1 and s2 are both nil.
    return ([s1 isEqualToString:s2] || s1 == s2);
}


@interface MPRenderer ()

@property (strong) NSMutableArray *currentLanguages;
@property (strong) id<MPMarkdownEngine> engine;
@property (readonly) NSArray *baseStylesheets;
@property (readonly) NSArray *prismStylesheets;
@property (readonly) NSArray *prismScripts;
@property (readonly) NSArray *mathjaxScripts;
@property (readonly) NSArray *mermaidStylesheets;
@property (readonly) NSArray *mermaidScripts;
@property (readonly) NSArray *graphvizScripts;
@property (readonly) NSArray *stylesheets;
@property (readonly) NSArray *scripts;
@property (copy) NSString *currentHtml;
@property (strong) NSOperationQueue *parseQueue;
@property (copy) MPMarkdownRenderOptions *markdownOptions;
@property (copy) NSString *styleName;
@property BOOL syntaxHighlighting;
@property BOOL mermaid;
@property BOOL graphviz;
@property MPCodeBlockAccessoryType codeBlockAccesory;
@property BOOL lineNumbers;
@property BOOL manualRender;
@property (copy) NSString *highlightingThemeName;

@end


@implementation MPRenderer

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    self.currentHtml = @"";
    self.currentLanguages = [NSMutableArray array];
    self.engine = [[MPCMarkEngine alloc] init];
    self.parseQueue = [[NSOperationQueue alloc] init];
    self.parseQueue.maxConcurrentOperationCount = 1; // Serial queue

    return self;
}

#pragma mark - Accessor

- (NSArray *)baseStylesheets
{
    NSMutableArray *stylesheets = [NSMutableArray array];
    NSString *defaultStyleName =
        MPStylePathForName([self.delegate rendererStyleName:self]);
    if (defaultStyleName)
    {
        NSURL *defaultStyle = [NSURL fileURLWithPath:defaultStyleName];
        [stylesheets addObject:[MPStyleSheet CSSWithURL:defaultStyle]];
    }

    // The YAML theme from ~/.config/macdown/config.yaml, if one is set. It
    // comes after the base style, so it can restyle it.
    NSURL *themeURL = [[MPThemeService shared] previewStylesheetURL];
    if (themeURL)
        [stylesheets addObject:[MPStyleSheet CSSWithURL:themeURL]];
    return stylesheets;
}

- (NSArray *)prismStylesheets
{
    NSString *name = [self.delegate rendererHighlightingThemeName:self];
    MPAsset *stylesheet =
        [MPStyleSheet CSSWithURL:MPHighlightingThemeURLForName(name)];

    NSMutableArray *stylesheets = [NSMutableArray arrayWithObject:stylesheet];

    if (self.markdownOptions.lineNumbers)
    {
        NSURL *url = MPPrismPluginURL(@"line-numbers", @"css");
        [stylesheets addObject:[MPStyleSheet CSSWithURL:url]];
    }
    if ([self.delegate rendererCodeBlockAccesory:self]
        == MPCodeBlockAccessoryLanguageName)
    {
        NSURL *url = MPPrismPluginURL(@"show-language", @"css");
        [stylesheets addObject:[MPStyleSheet CSSWithURL:url]];
    }

    return stylesheets;
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

    if (self.markdownOptions.lineNumbers)
    {
        NSURL *url = MPPrismPluginURL(@"line-numbers", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    if ([self.delegate rendererCodeBlockAccesory:self]
        == MPCodeBlockAccessoryLanguageName)
    {
        NSURL *url = MPPrismPluginURL(@"show-language", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    return scripts;
}

- (NSArray *)mathjaxScripts
{
    NSMutableArray *scripts = [NSMutableArray array];
    NSURL *url = [NSURL URLWithString:kMPMathJaxCDN];
    NSBundle *bundle = [NSBundle mainBundle];
    MPEmbeddedScript *script =
        [MPEmbeddedScript assetWithURL:[bundle URLForResource:@"init"
                                                withExtension:@"js"
                                                 subdirectory:@"MathJax"]
                               andType:kMPMathJaxConfigType];
    [scripts addObject:script];
    [scripts addObject:[MPScript javaScriptWithURL:url]];
    return scripts;
}

- (NSArray *)mermaidStylesheets
{
    NSMutableArray *stylesheets = [NSMutableArray array];
    
    NSURL *url = MPExtensionURL(@"mermaid.forest", @"css");
    [stylesheets addObject:[MPStyleSheet CSSWithURL:url]];
    
    return stylesheets;
}

- (NSArray *)mermaidScripts
{
    // TODO
    NSMutableArray *scripts = [NSMutableArray array];

    {
        NSURL *url = MPExtensionURL(@"mermaid.min", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    {
        NSURL *url = MPExtensionURL(@"mermaid.init", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    
    return scripts;
}

- (NSArray *)graphvizScripts
{
    // TODO
    NSMutableArray *scripts = [NSMutableArray array];

    {
        NSURL *url = MPExtensionURL(@"viz", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    {
        NSURL *url = MPExtensionURL(@"viz.init", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    
    return scripts;
}

- (NSArray *)stylesheets
{
    id<MPRendererDelegate> delegate = self.delegate;

    NSMutableArray *stylesheets = [self.baseStylesheets mutableCopy];
    if ([delegate rendererHasSyntaxHighlighting:self])
    {
        [stylesheets addObjectsFromArray:self.prismStylesheets];
        // mermaid
        if ([delegate rendererHasMermaid:self])
        {
            [stylesheets addObjectsFromArray:self.mermaidStylesheets];
        }
        
    }

    if ([delegate rendererCodeBlockAccesory:self] == MPCodeBlockAccessoryCustom)
    {
        NSURL *url = MPExtensionURL(@"show-information", @"css");
        [stylesheets addObject:[MPStyleSheet CSSWithURL:url]];
    }
    return stylesheets;
}

- (NSArray *)scripts
{
    id<MPRendererDelegate> d = self.delegate;
    NSMutableArray *scripts = [NSMutableArray array];
    if (self.markdownOptions.taskList)
    {
        NSURL *url = MPExtensionURL(@"tasklist", @"js");
        [scripts addObject:[MPScript javaScriptWithURL:url]];
    }
    if ([d rendererHasSyntaxHighlighting:self])
    {
        [scripts addObjectsFromArray:self.prismScripts];
        // mermaid
        if ([d rendererHasMermaid:self])
        {
            [scripts addObjectsFromArray:self.mermaidScripts];
        }
        // graphviz
        if ([d rendererHasGraphviz:self])
        {
            [scripts addObjectsFromArray:self.graphvizScripts];
        }
    }
    if ([d rendererHasMathJax:self])
        [scripts addObjectsFromArray:self.mathjaxScripts];
    return scripts;
}

#pragma mark - Public
    
- (void)parseAndRenderWithMaxDelay:(NSTimeInterval)maxDelay {
    [self.parseQueue cancelAllOperations];
    [self.parseQueue addOperationWithBlock:^{
        // Fetch the markdown (from the main thread)
        __block NSString *markdown;
        dispatch_sync(dispatch_get_main_queue(), ^{
            markdown = [[self.dataSource rendererMarkdown:self] copy];
        });

        // Parse in backgound
        [self parseMarkdown:markdown];
        
        // Wait untils is renderer has finished loading OR until the maxDelay has passed
        // This should result in overall faster update times
        NSDate *start = [NSDate date];
        __block BOOL rendererIsLoading = true;
        while (rendererIsLoading || [start timeIntervalSinceNow] >= maxDelay) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                rendererIsLoading = [self.dataSource rendererLoading];
            });
        }
        
        // Render on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self render];
        });
    }];
}

- (void)parseAndRenderNow
{
    [self parseAndRenderWithMaxDelay:0];
}

- (void)parseAndRenderLater
{
    [self parseAndRenderWithMaxDelay:0.5];
}

- (void)parseIfPreferencesChanged
{
    id<MPRendererDelegate> delegate = self.delegate;
    if (![[delegate rendererMarkdownOptions:self]
          isEqual:self.markdownOptions])
    {
        [self parseMarkdown:[self.dataSource rendererMarkdown:self]];
    }
}

- (void)parseMarkdown:(NSString *)markdown {
    id<MPRendererDelegate> delegate = self.delegate;
    MPMarkdownRenderOptions *options =
        [[delegate rendererMarkdownOptions:self] copy];

    MPMarkdownResult *result =
        [self.engine renderMarkdown:markdown options:options];
    self.currentHtml = result.html;
    self.currentLanguages = [result.languages mutableCopy];
    self.markdownOptions = options;
}

- (void)renderIfPreferencesChanged
{
    BOOL changed = NO;
    id<MPRendererDelegate> d = self.delegate;
    if ([d rendererHasSyntaxHighlighting:self] != self.syntaxHighlighting)
        changed = YES;
    else if ([d rendererHasMermaid:self] != self.mermaid)
        changed = YES;
    else if ([d rendererHasGraphviz:self] != self.graphviz)
        changed = YES;
    else if (!MPAreNilableStringsEqual(
            [d rendererHighlightingThemeName:self], self.highlightingThemeName))
        changed = YES;
    else if (!MPAreNilableStringsEqual(
            [d rendererStyleName:self], self.styleName))
        changed = YES;
    else if ([d rendererCodeBlockAccesory:self] != self.codeBlockAccesory)
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
    self.syntaxHighlighting = [delegate rendererHasSyntaxHighlighting:self];
    self.mermaid = [delegate rendererHasMermaid:self];
    self.graphviz = [delegate rendererHasGraphviz:self];
    self.highlightingThemeName = [delegate rendererHighlightingThemeName:self];
    self.codeBlockAccesory = [delegate rendererCodeBlockAccesory:self];
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
        if ([self.delegate rendererHasMermaid:self])
        {
            [styles addObjectsFromArray:self.mermaidStylesheets];
            [scripts addObjectsFromArray:self.mermaidScripts];
        }
        if ([self.delegate rendererHasGraphviz:self])
        {
            [scripts addObjectsFromArray:self.graphvizScripts];
        }

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

@end
