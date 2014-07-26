//
//  MPDocument.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 6/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPDocument.h"
#import <WebKit/WebKit.h>
#import <JJPluralForm/JJPluralForm.h>
#import <hoedown/html.h>
#import "hoedown_html_patch.h"
#import "HGMarkdownHighlighter.h"
#import "MPUtilities.h"
#import "NSString+Lookup.h"
#import "NSTextView+Autocomplete.h"
#import "MPPreferences.h"
#import "MPRenderer.h"
#import "MPExportPanelAccessoryViewController.h"


static NSString *MPEditorPreferenceKeyWithValueKey(NSString *key)
{
    if (!key.length)
        return @"editor";
    NSString *first = [[key substringToIndex:1] uppercaseString];
    NSString *rest = [key substringFromIndex:1];
    return [NSString stringWithFormat:@"editor%@%@", first, rest];
}

static NSDictionary *MPEditorKeysToObserve()
{
    static NSDictionary *keys = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        keys = @{@"automaticDashSubstitutionEnabled": @NO,
                 @"automaticDataDetectionEnabled": @NO,
                 @"automaticLinkDetectionEnabled": @NO,
                 @"automaticQuoteSubstitutionEnabled": @NO,
                 @"automaticSpellingCorrectionEnabled": @NO,
                 @"automaticTextReplacementEnabled": @NO,
                 @"continuousSpellCheckingEnabled": @NO,
                 @"enabledTextCheckingTypes": @(NSTextCheckingAllTypes),
                 @"grammarCheckingEnabled": @NO};
    });
    return keys;
}


@implementation NSString (WordCount)

- (NSUInteger)numberOfWords
{
    __block NSUInteger count = 0;
    NSStringEnumerationOptions options =
    NSStringEnumerationByWords | NSStringEnumerationSubstringNotRequired;
    [self enumerateSubstringsInRange:NSMakeRange(0, self.length)
                             options:options usingBlock:
     ^(NSString *str, NSRange strRange, NSRange enclosingRange, BOOL *stop) {
         count++;
     }];
    return count;
}

@end


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

- (int)rendererFlags
{
    int flags = 0;
    if (self.htmlTaskList)
        flags |= HOEDOWN_HTML_USE_TASK_LIST;
    if (self.htmlHardWrap)
        flags |= HOEDOWN_HTML_HARD_WRAP;
    return flags;
}
@end


@implementation NSSplitView (TwoItems)

- (void)setDividerLocation:(CGFloat)ratio
{
    NSArray *parts = self.subviews;
    NSAssert1(parts.count == 2, @"%@ should only be used on two-item splits.",
              NSStringFromSelector(_cmd));
    if (ratio < 0.0)
        ratio = 0.0;
    else if (ratio > 1.0)
        ratio = 1.0;
    CGFloat dividerThickness = self.dividerThickness;
    CGFloat totalWidth = self.frame.size.width - dividerThickness;
    CGFloat leftWidth = totalWidth * ratio;
    CGFloat rightWidth = totalWidth - leftWidth;
    NSView *left = parts[0];
    NSView *right = parts[1];

    left.frame = NSMakeRect(0.0, 0.0, leftWidth, left.frame.size.height);
    right.frame = NSMakeRect(leftWidth + dividerThickness, 0.0,
                             rightWidth, right.frame.size.height);
    [self setPosition:leftWidth ofDividerAtIndex:0];
}

- (void)swapViews
{
    NSArray *parts = self.subviews;
    NSView *left = parts[0];
    NSView *right = parts[1];
    self.subviews = @[right, left];
}

@end


@implementation DOMNode (Text)

- (NSString *)text
{
    NSMutableString *text = [NSMutableString string];
    switch (self.nodeType)
    {
        case 1:
        case 9:
        case 11:
            if (self.textContent.length)
                return self.textContent;
            for (DOMNode *c = self.firstChild; c; c = c.nextSibling)
                [text appendString:c.text];
            break;
        case 3:
        case 4:
            return self.nodeValue;
        default:
            break;
    }
    return text;
}

@end


@interface MPDocument ()
    <NSTextViewDelegate, MPRendererDataSource, MPRendererDelegate>

typedef NS_ENUM(NSUInteger, MPWordCountType) {
    MPWordCountTypeWord,
    MPWordCountTypeCharacter,
    MPWordCountTypeCharacterNoSpaces,
};

@property (weak) IBOutlet NSSplitView *splitView;
@property (unsafe_unretained) IBOutlet NSTextView *editor;
@property (weak) IBOutlet NSLayoutConstraint *editorPaddingBottom;
@property (weak) IBOutlet WebView *preview;
@property (weak) IBOutlet NSPopUpButton *wordCountWidget;
@property (strong) HGMarkdownHighlighter *highlighter;
@property (strong) MPRenderer *renderer;
@property BOOL manualRender;
@property BOOL previewFlushDisabled;
@property (readonly) BOOL previewVisible;
@property (nonatomic) NSUInteger totalWords;
@property (nonatomic) NSUInteger totalCharacters;
@property (nonatomic) NSUInteger totalCharactersNoSpaces;
@property (strong) NSMenuItem *wordsMenuItem;
@property (strong) NSMenuItem *charMenuItem;
@property (strong) NSMenuItem *charNoSpacesMenuItem;

// Store file content in initializer until nib is loaded.
@property (copy) NSString *loadedString;

@end


@implementation MPDocument


#pragma mark - Accessor

- (MPPreferences *)preferences
{
    return [MPPreferences sharedInstance];
}

- (BOOL)previewVisible
{
    return self.preview.frame.size.width;
}

- (void)setTotalWords:(NSUInteger)value
{
    _totalWords = value;
    NSString *key = NSLocalizedString(@"WORDS_PLURAL_STRING", @"");
    NSInteger rule = kJJPluralFormRule.integerValue;
    self.wordsMenuItem.title =
        [JJPluralForm pluralStringForNumber:value withPluralForms:key
                            usingPluralRule:rule localizeNumeral:NO];
}

- (void)setTotalCharacters:(NSUInteger)value
{
    _totalCharacters = value;
    NSString *key = NSLocalizedString(@"CHARACTERS_PLURAL_STRING", @"");
    NSInteger rule = kJJPluralFormRule.integerValue;
    self.charMenuItem.title =
        [JJPluralForm pluralStringForNumber:value withPluralForms:key
                            usingPluralRule:rule localizeNumeral:NO];
}

- (void)setTotalCharactersNoSpaces:(NSUInteger)value
{
    _totalCharactersNoSpaces = value;
    NSString *key = NSLocalizedString(@"CHARACTERS_NO_SPACES_PLURAL_STRING",
                                      @"");
    NSInteger rule = kJJPluralFormRule.integerValue;
    self.charNoSpacesMenuItem.title =
        [JJPluralForm pluralStringForNumber:value withPluralForms:key
                            usingPluralRule:rule localizeNumeral:NO];
}


#pragma mark - Override

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
    self.splitView.autosaveName = autosaveName;

    self.highlighter =
        [[HGMarkdownHighlighter alloc] initWithTextView:self.editor
                                           waitInterval:0.1];
    self.renderer = [[MPRenderer alloc] init];
    self.renderer.dataSource = self;
    self.renderer.delegate = self;

    [self setupEditor];
    for (NSString *key in MPEditorKeysToObserve())
    {
        [self.editor addObserver:self forKeyPath:key
                         options:NSKeyValueObservingOptionNew context:NULL];
    }

    self.preview.frameLoadDelegate = self;
    self.preview.policyDelegate = self;

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

    if (self.loadedString)
    {
        self.editor.string = self.loadedString;
        self.loadedString = nil;
        [self.renderer parseAndRenderNow];
        [self.highlighter parseAndHighlightNow];
    }
    
    if (self.preferences.editorOnRight)
        [self.splitView swapViews];

    self.wordsMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL
                                             keyEquivalent:@""];
    self.charMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL
                                            keyEquivalent:@""];
    self.charNoSpacesMenuItem = [[NSMenuItem alloc] initWithTitle:@""
                                                           action:NULL
                                                    keyEquivalent:@""];

    NSPopUpButton *wordCountWidget = self.wordCountWidget;
    [wordCountWidget removeAllItems];
    [wordCountWidget.menu addItem:self.wordsMenuItem];
    [wordCountWidget.menu addItem:self.charMenuItem];
    [wordCountWidget.menu addItem:self.charNoSpacesMenuItem];
    [wordCountWidget selectItemAtIndex:self.preferences.editorWordCountType];
    wordCountWidget.alphaValue = 0.9;
    wordCountWidget.hidden = !self.preferences.editorShowWordCount;
}

- (void)canCloseDocumentWithDelegate:(id)delegate
                 shouldCloseSelector:(SEL)selector contextInfo:(void *)context
{
    selector = @selector(document:shouldClose:contextInfo:);
    [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:selector
                            contextInfo:context];
}

- (void)document:(NSDocument *)doc shouldClose:(BOOL)shouldClose
     contextInfo:(void *)contextInfo
{
    if (!shouldClose)
        return;

    // Need to cleanup these so that callbacks won't crash the app.
    [self.highlighter deactivate];
    self.highlighter.targetTextView = nil;
    self.highlighter = nil;
    self.renderer = nil;
    self.preview.frameLoadDelegate = nil;
    self.preview.policyDelegate = nil;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:NSTextDidChangeNotification
                    object:self.editor];
    [center removeObserver:self name:NSUserDefaultsDidChangeNotification
                    object:[NSUserDefaults standardUserDefaults]];
    [center removeObserver:self name:NSViewBoundsDidChangeNotification
                    object:self.editor.enclosingScrollView.contentView];
    for (NSString *key in MPEditorKeysToObserve())
        [self.editor removeObserver:self forKeyPath:key];

    [self close];
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

+ (NSArray *)writableTypes
{
    return @[@"net.daringfireball.markdown"];
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

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
    NSString *title = [self.editor.string titleString];
    if (title)
        savePanel.nameFieldStringValue = title;
    savePanel.allowedFileTypes = nil;   // Allow all extensions.
    return [super prepareSavePanel:savePanel];
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
    else if (commandSelector == @selector(moveToLeftEndOfLine:))
        return ![self textViewShouldMoveToLeftEndOfLine:textView];
    return NO;
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)range
                                              replacementString:(NSString *)str
{
    // Ignore if this originates from an IM marked text commit event.
    if (NSIntersectionRange(textView.markedRange, range).length)
        return YES;

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
    if ([textView completeNextListItem])
        return NO;
    if ([textView completeNextBlockquoteLine])
        return NO;
    return YES;
}

- (BOOL)textViewShouldDeleteBackward:(NSTextView *)textView
{
    if (self.preferences.editorCompleteMatchingCharacters)
    {
        NSUInteger location = self.editor.selectedRange.location;
        [textView deleteMatchingCharactersAround:location];
    }
    if (self.preferences.editorConvertTabs)
    {
        NSUInteger location = self.editor.selectedRange.location;
        [textView unindentForSpacesBefore:location];
    }
    return YES;
}

- (BOOL)textViewShouldMoveToLeftEndOfLine:(NSTextView *)textView
{
    if (!self.preferences.editorSmartHome)
        return YES;
    NSUInteger cur = textView.selectedRange.location;
    NSUInteger location =
        [textView.string locationOfFirstNonWhitespaceCharacterInLineBefore:cur];
    if (location == cur)
        return YES;
    textView.selectedRange = NSMakeRange(location, 0);
    return NO;
}


#pragma mark - WebFrameLoadDelegate

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
{
    if (!self.previewFlushDisabled && sender.window)
    {
        self.previewFlushDisabled = YES;
        [sender.window disableFlushWindow];
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (self.previewFlushDisabled)
        {
            [sender.window enableFlushWindow];
            self.previewFlushDisabled = NO;
        }
        [self syncScrollers];
    }];
    
    // Update word count
    if (self.preferences.editorShowWordCount)
    {
        static NSRegularExpression *regex = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            regex = [NSRegularExpression regularExpressionWithPattern:@"\\s"
                                                              options:0
                                                                error:NULL];
        });

        NSString *text = sender.mainFrame.DOMDocument.text;
        NSCharacterSet *sp = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSString *trimmedDocument = [text stringByTrimmingCharactersInSet:sp];
        NSString *noWhitespace =
            [regex stringByReplacingMatchesInString:text options:0
                                              range:NSMakeRange(0, text.length)
                                       withTemplate:@""];

        self.totalWords = text.numberOfWords;
        self.totalCharacters = trimmedDocument.length;
        self.totalCharactersNoSpaces = noWhitespace.length;
    }
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error
       forFrame:(WebFrame *)frame
{
    [self webView:sender didFinishLoadForFrame:frame];
}


#pragma mark - WebPolicyDelegate

- (void)webView:(WebView *)webView
                decidePolicyForNavigationAction:(NSDictionary *)information
        request:(NSURLRequest *)request frame:(WebFrame *)frame
                decisionListener:(id<WebPolicyDecisionListener>)listener
{
    switch ([information[WebActionNavigationTypeKey] integerValue])
    {
        case WebNavigationTypeLinkClicked:
            [listener ignore];
            [[NSWorkspace sharedWorkspace] openURL:request.URL];
            break;
        default:
            [listener use];
            break;
    }
}


#pragma mark - MPRendererDataSource

- (NSString *)rendererMarkdown:(MPRenderer *)renderer
{
    return self.editor.string;
}

- (NSString *)rendererHTMLTitle:(MPRenderer *)renderer
{
    NSString *name = self.fileURL.lastPathComponent;

    // TODO: Detect extensions from bundle info directly. Don't hardcode.
    if ([name hasSuffix:@".md"])
        name = [name substringToIndex:name.length - 3];
    else if ([name hasSuffix:@".markdown"])
        name = [name substringToIndex:name.length - 9];

    if (name.length)
        return name;
    return @"";
}


#pragma mark - MPRendererDelegate

- (int)rendererExtensions:(MPRenderer *)renderer
{
    return self.preferences.extensionFlags;
}

- (BOOL)rendererHasSmartyPants:(MPRenderer *)renderer
{
    return self.preferences.extensionSmartyPants;
}

- (NSString *)rendererStyleName:(MPRenderer *)renderer
{
    return self.preferences.htmlStyleName;
}

- (BOOL)rendererDetectsFrontMatter:(MPRenderer *)renderer
{
    return self.preferences.htmlDetectFrontMatter;
}

- (BOOL)rendererHasSyntaxHighlighting:(MPRenderer *)renderer
{
    return self.preferences.htmlSyntaxHighlighting;
}

- (BOOL)rendererHasMathJax:(MPRenderer *)renderer
{
    return self.preferences.htmlMathJax;
}

- (BOOL)rendererMathJaxInlineDollarEnabled:(MPRenderer *)renderer
{
    return self.preferences.htmlMathJaxInlineDollar;
}

- (NSString *)rendererHighlightingThemeName:(MPRenderer *)renderer
{
    return self.preferences.htmlHighlightingThemeName;
}

- (void)renderer:(MPRenderer *)renderer didProduceHTMLOutput:(NSString *)html
{
    self.manualRender = self.preferences.markdownManualRender;
    NSURL *baseUrl = self.fileURL;
    if (!baseUrl)
        baseUrl = self.preferences.htmlDefaultDirectoryUrl;
    [self.preview.mainFrame loadHTMLString:html baseURL:baseUrl];
}


#pragma mark - Notification handler

- (void)textDidChange:(NSNotification *)notification
{
    if (!self.preferences.markdownManualRender && self.previewVisible)
        [self.renderer parseAndRenderLater];
}

- (void)userDefaultsDidChange:(NSNotification *)notification
{
    MPRenderer *renderer = self.renderer;

    // Force update if we're switching from manual to auto, or renderer settings
    // changed.
    int rendererFlags = self.preferences.rendererFlags;
    if ((!self.preferences.markdownManualRender && self.manualRender)
            || renderer.rendererFlags != rendererFlags)
    {
        renderer.rendererFlags = rendererFlags;
        [renderer parseAndRenderLater];
    }
    else
    {
        [renderer parseNowWithCommand:@selector(parseIfPreferencesChanged)
                      completionHandler:^{
                          [renderer render];
                      }];
        [renderer renderIfPreferencesChanged];
    }

    if (self.highlighter.isActive)
        [self setupEditor];

    NSArray *parts = self.splitView.subviews;
    if ((self.preferences.editorOnRight && parts[1] == self.preview)
            || (!self.preferences.editorOnRight && parts[0] == self.preview))
        [self.splitView swapViews];

    if (self.preferences.editorShowWordCount)
    {
        self.wordCountWidget.hidden = NO;
        self.editorPaddingBottom.constant = 35.0;
    }
    else
    {
        self.wordCountWidget.hidden = YES;
        self.editorPaddingBottom.constant = 0.0;
    }
    self.splitView.needsLayout = YES;
}

- (void)boundsDidChange:(NSNotification *)notification
{
    static BOOL shouldHandleNotification = YES;
    if (shouldHandleNotification) {
        shouldHandleNotification = NO;
        CGFloat clipWidth = [notification.object frame].size.width;
        NSRect editorFrame = self.editor.frame;
        if (editorFrame.size.width != clipWidth)
        {
            editorFrame.size.width = clipWidth;
            self.editor.frame = editorFrame;
        }
        [self syncScrollers];
        shouldHandleNotification = YES;
    }
}


#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
    if (object == self.editor)
    {
        if (!self.highlighter.isActive)
            return;
        id value = change[NSKeyValueChangeNewKey];
        NSString *preferenceKey = MPEditorPreferenceKeyWithValueKey(keyPath);
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:value forKey:preferenceKey];
    }
}


#pragma mark - IBAction

- (IBAction)printDocument:(id)sender
{
    NSPrintOperation *operation =
        [NSPrintOperation printOperationWithView:self.preview];
    [operation runOperationModalForWindow:self.windowForSheet
                                 delegate:nil didRunSelector:NULL
                              contextInfo:NULL];
}

- (IBAction)copyHtml:(id)sender
{
    // Dis-select things in WebView so that it's more obvious we're NOT
    // respecting the selection range.
    [self.preview setSelectedDOMRange:nil affinity:NSSelectionAffinityUpstream];

    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard writeObjects:@[self.renderer.currentHtml]];
}

- (IBAction)exportHtml:(id)sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedFileTypes = @[@"html"];
    if (self.fileURL)
    {
        NSString *fileName = self.fileURL.lastPathComponent;
        if ([fileName hasSuffix:@".md"])
            fileName = [fileName substringToIndex:(fileName.length - 3)];
        panel.nameFieldStringValue = fileName;
    }

    MPExportPanelAccessoryViewController *controller =
        [[MPExportPanelAccessoryViewController alloc] init];
    panel.accessoryView = controller.view;

    NSWindow *w = self.windowForSheet;
    [panel beginSheetModalForWindow:w completionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton)
            return;
        BOOL styles = controller.stylesIncluded;
        BOOL highlighting = controller.highlightingIncluded;
        NSString *html = [self.renderer HTMLForExportWithStyles:styles
                                                   highlighting:highlighting];
        [html writeToURL:panel.URL atomically:NO encoding:NSUTF8StringEncoding
                   error:NULL];
    }];
}

- (IBAction)convertToH1:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:1];
}

- (IBAction)convertToH2:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:2];
}

- (IBAction)convertToH3:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:3];
}

- (IBAction)convertToH4:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:4];
}

- (IBAction)convertToH5:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:5];
}

- (IBAction)convertToH6:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:6];
}

- (IBAction)convertToParagraph:(id)sender
{
    [self.editor makeHeaderForSelectedLinesWithLevel:0];
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

- (IBAction)toggleLink:(id)sender
{
    if ([self.editor toggleForMarkupPrefix:@"[" suffix:@"]()"])
    {
        NSRange selectedRange = self.editor.selectedRange;
        NSUInteger location = selectedRange.location + selectedRange.length + 2;
        self.editor.selectedRange = NSMakeRange(location, 0);
    }
}

- (IBAction)toggleImage:(id)sender
{
    if ([self.editor toggleForMarkupPrefix:@"![" suffix:@"]()"])
    {
        NSRange selectedRange = self.editor.selectedRange;
        NSUInteger location = selectedRange.location + selectedRange.length + 2;
        self.editor.selectedRange = NSMakeRange(location, 0);
    }
}

- (IBAction)toggleUnorderedList:(id)sender
{
    [self.editor toggleBlockWithPattern:@"^[\\*\\+-] \\S" prefix:@"* "];
}

- (IBAction)toggleBlockquote:(id)sender
{
    [self.editor toggleBlockWithPattern:@"^> \\S" prefix:@"> "];
}

- (IBAction)indent:(id)sender
{
    NSString *padding = @"\t";
    if (self.preferences.editorConvertTabs)
        padding = @"    ";
    [self.editor indentSelectedLinesWithPadding:padding];
}

- (IBAction)unindent:(id)sender
{
    [self.editor unindentSelectedLines];
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

- (IBAction)insertAmp:(id)sender
{
    [self.editor insertText:@"&amp;"];
}

- (IBAction)insertLt:(id)sender
{
    [self.editor insertText:@"&lt;"];
}

- (IBAction)insertGt:(id)sender
{
    [self.editor insertText:@"&gt;"];
}

- (IBAction)insertNbsp:(id)sender
{
    [self.editor insertText:@"&nbsp;"];
}

- (IBAction)insertQuot:(id)sender
{
    [self.editor insertText:@"&quot;"];
}

- (IBAction)insert39:(id)sender
{
    [self.editor insertText:@"&#39;"];
}

- (IBAction)setEditorOneQuarter:(id)sender
{
    [self setSplitViewDividerLocation:0.25];
}

- (IBAction)setEditorThreeQuarters:(id)sender
{
    [self setSplitViewDividerLocation:0.75];
}

- (IBAction)setEqualSplit:(id)sender
{
    [self setSplitViewDividerLocation:0.5];
}

- (IBAction)hidePreivewPane:(id)sender
{
    if (self.preferences.editorOnRight)
        [self setSplitViewDividerLocation:0.0];
    else
        [self setSplitViewDividerLocation:1.0];
}

- (IBAction)render:(id)sender
{
    [self.renderer parseAndRenderLater];
}


#pragma mark - Private

- (void)setupEditor
{
    [self.highlighter deactivate];
    self.editor.font = [self.preferences.editorBaseFont copy];

    int extensions = pmh_EXT_NOTES;
    if (self.preferences.extensionFootnotes)
        extensions = pmh_EXT_NONE;
    self.highlighter.extensions = extensions;

    CGFloat x = self.preferences.editorHorizontalInset;
    CGFloat y = self.preferences.editorVerticalInset;
    self.editor.textContainerInset = NSMakeSize(x, y);

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = self.preferences.editorLineSpacing;
    self.editor.defaultParagraphStyle = [style copy];

    self.editor.textColor = nil;
    self.editor.backgroundColor = nil;
    self.highlighter.styles = nil;
    [self.highlighter readClearTextStylesFromTextView];

    NSString *themeName = [self.preferences.editorStyleName copy];
    if (themeName.length)
    {
        NSString *path = MPThemePathForName(themeName);
        NSString *themeString = MPReadFileOfPath(path);
        [self.highlighter applyStylesFromStylesheet:themeString
                                   withErrorHandler:
            ^(NSArray *errorMessages) {
                self.preferences.editorStyleName = nil;
            }];
    }

    // Have to keep this enabled because HGMarkdownHighlighter needs them.
    NSClipView *contentView = self.editor.enclosingScrollView.contentView;
    contentView.postsBoundsChangedNotifications = YES;

    NSDictionary *keysAndDefaults = MPEditorKeysToObserve();
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSString *key in keysAndDefaults)
    {
        NSString *preferenceKey = MPEditorPreferenceKeyWithValueKey(key);
        id value = [defaults objectForKey:preferenceKey];
        value = value ? value : keysAndDefaults[key];
        [self.editor setValue:value forKey:key];
    }

    NSView *editorChrome = self.editor.enclosingScrollView.superview;
    CALayer *layer = [CALayer layer];
    layer.backgroundColor = self.editor.backgroundColor.CGColor;
    editorChrome.wantsLayer = YES;
    editorChrome.layer = layer;

    [self.highlighter activate];
}

- (void)syncScrollers
{
    if (!self.preferences.editorSyncScrolling)
        return;

    NSScrollView *editorScrollView = self.editor.enclosingScrollView;
    NSClipView *editorContentView = editorScrollView.contentView;
    NSView *editorDocumentView = editorScrollView.documentView;
    NSRect editorDocumentFrame = editorDocumentView.frame;
    NSRect editorContentBounds = editorContentView.bounds;
    CGFloat ratio = 0.0;
    if (editorDocumentFrame.size.height > editorContentBounds.size.height)
    {
        ratio = editorContentBounds.origin.y /
            (editorDocumentFrame.size.height - editorContentBounds.size.height);
    }

    NSScrollView *previewScrollView =
        self.preview.mainFrame.frameView.documentView.enclosingScrollView;
    NSClipView *previewContentView = previewScrollView.contentView;
    NSView *previewDocumentView = previewScrollView.documentView;
    NSRect previewContentBounds = previewContentView.bounds;
    previewContentBounds.origin.y =
        ratio * (previewDocumentView.frame.size.height
                 - previewContentBounds.size.height);
    previewContentView.bounds = previewContentBounds;
}

- (void)setSplitViewDividerLocation:(CGFloat)ratio
{
    BOOL wasVisible = self.previewVisible;
    [self.splitView setDividerLocation:ratio];
    if (!wasVisible && self.previewVisible
            && !self.preferences.markdownManualRender)
        [self.renderer parseAndRenderNow];
}

@end
