//
//  MPDocument.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 6/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPDocument.h"
#import <WebKit/WebKit.h>
#import <hoedown/html.h>
#import <hoedown/markdown.h>
#import "HGMarkdownHighlighter.h"
#import "MPUtilities.h"
#import "NSString+Lookup.h"
#import "NSTextView+Autocomplete.h"
#import "MPPreferences.h"


@implementation MPPreferences (Hoedown)
- (int)extensionFlags
{
    int flags = HOEDOWN_EXT_LAX_SPACING;
    if (self.extensionAutolink)
        flags |= HOEDOWN_EXT_AUTOLINK;
    if (self.extensionFencedCode)
        flags |= HOEDOWN_EXT_FENCED_CODE;
    if (self.extensionFootnotes)
        flags |= HOEDOWN_EXT_FOOTNOTES;
    if (self.extensionHighlight)
        flags |= HOEDOWN_EXT_HIGHLIGHT;
    if (!self.extensionIntraEmphasis)
        flags |= HOEDOWN_EXT_NO_INTRA_EMPHASIS;
    if (self.extensionQuote)
        flags |= HOEDOWN_EXT_QUOTE;
    if (self.extensionStrikethough)
        flags |= HOEDOWN_EXT_STRIKETHROUGH;
    if (self.extensionSuperscript)
        flags |= HOEDOWN_EXT_SUPERSCRIPT;
    if (self.extensionTables)
        flags |= HOEDOWN_EXT_TABLES;
    if (self.extensionUnderline)
        flags |= HOEDOWN_EXT_UNDERLINE;
    return flags;
}
@end


@interface MPDocument () <NSTextViewDelegate>

@property (unsafe_unretained) IBOutlet NSTextView *editor;
@property (weak) IBOutlet WebView *preview;
@property (unsafe_unretained) hoedown_renderer *htmlRenderer;
@property HGMarkdownHighlighter *highlighter;
@property int currentExtensionFlags;
@property BOOL currentSmartyPantsFlag;
@property (copy) NSString *currentHtml;
@property (copy) NSString *currentStyleName;

// Store file content in initializer until nib is loaded.
@property (copy) NSString *loadedString;

@end


@implementation MPDocument

- (id)init
{
    self = [super init];
    if (!self)
        return self;

    self.htmlRenderer = hoedown_html_renderer_new(0, 0);

    return self;
}

- (void)dealloc
{
    if (_htmlRenderer)
    {
        hoedown_html_renderer_free(_htmlRenderer);
        _htmlRenderer = NULL;
    }
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self
                      name:NSTextDidChangeNotification
                    object:self.editor];
    [center removeObserver:self
                      name:NSUserDefaultsDidChangeNotification
                    object:[NSUserDefaults standardUserDefaults]];
    [center removeObserver:self
                      name:NSViewBoundsDidChangeNotification
                    object:self.editor.enclosingScrollView.contentView];
}


#pragma mark - Accessor

- (MPPreferences *)preferences
{
    return [MPPreferences sharedInstance];
}


#pragma mark - Public

- (NSString *)windowNibName
{
    return @"MPDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)controller
{
    [super windowControllerDidLoadNib:controller];

    // All files use their absolute path to keep their window states.
    // New files share a common autosave name so that we can get a preferred
    // window size when creating new documents.
    NSString *autosaveName = @"Markdown";
    if (self.fileURL)
        autosaveName = self.fileURL.absoluteString;
    controller.window.frameAutosaveName = autosaveName;

    self.highlighter =
        [[HGMarkdownHighlighter alloc] initWithTextView:self.editor
                                           waitInterval:0.2];
    self.highlighter.parseAndHighlightAutomatically = YES;

    // Fix Xcod 5/Lion bug where disselecting options in OB doesn't work.
    // TODO: Can we save/set these app-wise using KVO?
    self.editor.automaticQuoteSubstitutionEnabled = NO;
    self.editor.automaticLinkDetectionEnabled = NO;
    self.editor.automaticDashSubstitutionEnabled = NO;

    [self setupEditor];
    if (self.loadedString)
    {
        self.editor.string = self.loadedString;
        self.loadedString = nil;
        [self parse];
        [self render];
    }

    self.preview.frameLoadDelegate = self;
    self.preview.policyDelegate = self;

    [self.highlighter activate];
    [self.highlighter parseAndHighlightNow];    // Initial highlighting

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(textDidChange:)
                   name:NSTextDidChangeNotification
                 object:self.editor];
    [center addObserver:self
               selector:@selector(userDefaultsDidChange:)
                   name:NSUserDefaultsDidChangeNotification
                 object:[NSUserDefaults standardUserDefaults]];
    [center addObserver:self
               selector:@selector(boundsDidChange:)
                   name:NSViewBoundsDidChangeNotification
                 object:self.editor.enclosingScrollView.contentView];
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    return [self.editor.string dataUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName
               error:(NSError **)outError
{
    self.loadedString = [[NSString alloc] initWithData:data
                                              encoding:NSUTF8StringEncoding];
    return YES;
}


#pragma mark - NSTextViewDelegate

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertTab:))
        return ![self textViewShouldInsertTab:textView];
    else if (commandSelector == @selector(insertNewline:))
        return ![self textViewShouldInsertNewline:textView];
    else if (commandSelector == @selector(deleteBackward:))
        return ![self textViewShouldDeleteBackward:textView];
    return NO;
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)range
                                              replacementString:(NSString *)str
{
    if (self.preferences.editorCompleteMatchingCharacters)
    {
        BOOL strikethrough = self.preferences.extensionStrikethough;
        if ([textView completeMatchingCharactersForTextInRange:range
                                                    withString:str
                                          strikethroughEnabled:strikethrough])
            return NO;
    }
    return YES;
}


#pragma mark - Fake NSTextViewDelegate

- (BOOL)textViewShouldInsertTab:(NSTextView *)textView
{
    if (self.preferences.editorConvertTabs)
    {
        [textView insertSpacesForTab];
        return NO;
    }
    return YES;
}

- (BOOL)textViewShouldInsertNewline:(NSTextView *)textView
{
    if ([textView insertMappedContent])
        return NO;
    if ([textView completeListContinuation])
        return NO;
    return YES;
}

- (BOOL)textViewShouldDeleteBackward:(NSTextView *)textView
{
    if (self.preferences.editorCompleteMatchingCharacters)
    {
        NSUInteger location = self.editor.selectedRange.location;
        if ([textView deleteMatchingCharactersAround:location])
            return NO;
    }
    if (self.preferences.editorConvertTabs)
    {
        NSUInteger location = self.editor.selectedRange.location;
        if ([textView unindentForSpacesBefore:location])
            return NO;
    }
    return YES;
}


#pragma mark - WebFrameLoadDelegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    if (self.preferences.editorSyncScrolling)
        [self syncScrollers];
}


#pragma mark - WebPolicyDelegate

- (void)webView:(WebView *)webView
                decidePolicyForNavigationAction:(NSDictionary *)information
        request:(NSURLRequest *)request frame:(WebFrame *)frame
                decisionListener:(id<WebPolicyDecisionListener>)listener
{
    [listener ignore];
    [[NSWorkspace sharedWorkspace] openURL:request.URL];
}


#pragma mark - Notification handler

- (void)textDidChange:(NSNotification *)notification
{
    [self parse];
    [self render];
}

- (void)userDefaultsDidChange:(NSNotification *)notification
{
    if ([self parseIfPreferencesChanged])
        [self render];
    else
        [self renderIfPreferencesChanged];
    [self setupEditor];
}

- (void)boundsDidChange:(NSNotification *)notification
{
    [self syncScrollers];
}


#pragma mark - IBAction

- (IBAction)copyHtml:(id)sender
{
    // Dis-select things in WebView so that it's more obvious we're NOT
    // respecting the selection range.
    [self.preview setSelectedDOMRange:nil affinity:NSSelectionAffinityUpstream];

    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard writeObjects:@[self.currentHtml]];
}

- (IBAction)toggleStrong:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"**" suffix:@"**"];
}

- (IBAction)toggleEmphasis:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"*" suffix:@"*"];
}

- (IBAction)toggleInlineCode:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"`" suffix:@"`"];
}

- (IBAction)toggleStrikethrough:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"~~" suffix:@"~~"];
}

- (IBAction)toggleUnderline:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"_" suffix:@"_"];
}

- (IBAction)toggleHighlight:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"==" suffix:@"=="];
}

- (IBAction)toggleComment:(id)sender
{
    [self.editor toggleForMarkupPrefix:@"<!--" suffix:@"-->"];
}

- (IBAction)insertNewParagraph:(id)sender
{
    NSRange range = self.editor.selectedRange;
    NSUInteger location = range.location;
    NSUInteger length = range.length;
    NSString *content = self.editor.string;
    NSInteger newlineBefore = [content locationOfFirstNewlineBefore:location];
    NSUInteger newlineAfter =
        [content locationOfFirstNewlineAfter:location + length - 1];

    // This is an empty line. Treat as normal return key.
    if (location == newlineBefore + 1 && location == newlineAfter)
    {
        [self.editor insertNewline:self];
        return;
    }

    // Insert two newlines after the current line, and jump to there.
    self.editor.selectedRange = NSMakeRange(newlineAfter, 0);
    [self.editor insertText:@"\n\n"];
}


#pragma mark - Private

- (void)setupEditor
{
    self.editor.font = [self.preferences.editorBaseFont copy];

    CGFloat x = self.preferences.editorHorizontalInset;
    CGFloat y = self.preferences.editorVerticalInset;
    self.editor.textContainerInset = NSMakeSize(x, y);

    NSString *themeName = [self.preferences.editorStyleName copy];
    if (!themeName.length)
    {
        self.editor.textColor = nil;
        self.editor.backgroundColor = nil;
        self.highlighter.styles = nil;
        [self.highlighter readClearTextStylesFromTextView];
    }
    else
    {
        NSString *themeString = [self themeStringForName:themeName];
        [self.highlighter applyStylesFromStylesheet:themeString
                                   withErrorHandler:
            ^(NSArray *errorMessages) {
                self.preferences.editorStyleName = nil;
            }];
    }

    // Have to keep this enabled because HGMarkdownHighlighter needs them.
    NSClipView *contentView = self.editor.enclosingScrollView.contentView;
    contentView.postsBoundsChangedNotifications = YES;
}

- (void)syncScrollers
{
    // TODO: There should be a better algorithm for calculating offsets. But
    // even Ghost's editor basically only go this far, so...
    NSScrollView *editorScroll = self.editor.enclosingScrollView;
    NSRect editorBounds = editorScroll.contentView.bounds;
    CGFloat editorY = editorBounds.origin.y;
    CGFloat ratio = editorY / [editorScroll.documentView frame].size.height;

    NSString *javaScriptCode = [NSString stringWithFormat:
        @"window.scrollTo(0, document.body.scrollHeight * %lf)", ratio];
    [self.preview stringByEvaluatingJavaScriptFromString:javaScriptCode];
}

- (NSString *)styleStringForName:(NSString *)name
{
    if (![name hasSuffix:kMPStyleFileExtension])
        name = [NSString stringWithFormat:@"%@%@", name, kMPStyleFileExtension];
    NSString *path = MPPathToDataFile(name, kMPStylesDirectoryName);
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        return nil;

    NSError *error = nil;
    NSString *content =
        [[NSString alloc] initWithContentsOfFile:path
                                        encoding:NSUTF8StringEncoding
                                           error:&error];
    if (error)
        return nil;
    return content;
}

- (NSString *)themeStringForName:(NSString *)name
{
    if (![name hasSuffix:kMPThemeFileExtension])
        name = [NSString stringWithFormat:@"%@%@", name, kMPThemeFileExtension];
    NSString *path = MPPathToDataFile(name, kMPThemesDirectoryName);
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        return nil;

    NSError *error = nil;
    NSString *content =
    [[NSString alloc] initWithContentsOfFile:path
                                    encoding:NSUTF8StringEncoding
                                       error:&error];
    if (error)
        return nil;
    return content;
}

- (void)parse
{
    int flags = self.preferences.extensionFlags;
    BOOL smartyPants = self.preferences.extensionSmartyPants;

    NSString *source = self.editor.string;
    self.currentHtml = [self htmlFromText:source
                          withSmartyPants:smartyPants flags:flags];

    // Record current parsing flags for -parseIfPreferencesChanged.
    self.currentExtensionFlags = flags;
    self.currentSmartyPantsFlag = smartyPants;
}

- (BOOL)parseIfPreferencesChanged
{
    if (self.preferences.extensionFlags != self.currentExtensionFlags
        | self.preferences.extensionSmartyPants != self.currentSmartyPantsFlag)
    {
        [self parse];
        return YES;
    }
    return NO;
}

- (void)render
{
    NSString *styleName = [self.preferences.htmlStyleName copy];
    NSString *styleString = [self styleStringForName:styleName];
    NSString *html = [self htmlDocumentFromBody:self.currentHtml
                                         styles:styleString];

    NSURL *baseUrl = self.fileURL;
    if (!baseUrl)
        baseUrl = self.preferences.htmlDefaultDirectoryUrl;
    [self.preview.mainFrame loadHTMLString:html baseURL:baseUrl];

    // Record current rendering flags for -renderIfPreferencesChanged.
    self.currentStyleName = styleName;
}

- (BOOL)renderIfPreferencesChanged
{
    if (self.preferences.htmlStyleName != self.currentStyleName)
    {
        [self render];
        return YES;
    }
    return NO;
}

- (NSString *)htmlFromText:(NSString *)text
           withSmartyPants:(BOOL)smartyPantsEnabled flags:(int)flags
{
    NSData *inputData = [text dataUsingEncoding:NSUTF8StringEncoding];

    hoedown_markdown *markdown =
        hoedown_markdown_new(flags, 15, self.htmlRenderer);

    hoedown_buffer *ib = hoedown_buffer_new(64);
    hoedown_buffer *ob = hoedown_buffer_new(64);

    const uint8_t *data = 0;
    size_t size = 0;
    if (smartyPantsEnabled)
    {
        hoedown_html_smartypants(ib, inputData.bytes, inputData.length);
        data = ib->data;
        size = ib->size;
    }
    else
    {
        data = inputData.bytes;
        size = inputData.length;
    }
    hoedown_markdown_render(ob, data, size, markdown);

    NSString *result = [NSString stringWithUTF8String:hoedown_buffer_cstr(ob)];

    hoedown_markdown_free(markdown);
    hoedown_buffer_free(ib);
    hoedown_buffer_free(ob);

    return result;
}

- (NSString *)htmlDocumentFromBody:(NSString *)body styles:(NSString *)styles
{
    if (!styles)
        styles = @"";

    return [NSString stringWithFormat:@"<!DOCTYPE html>"
            @"<html lang=\"en\"><head><meta charset=\"utf-8\">"
            @"<title>%@</title><style>%@</style></head>"
            @"<body>%@</body></html>",
            self.displayName, styles, body];
}

@end
