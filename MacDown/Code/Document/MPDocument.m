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
#import "MPAutosaving.h"
#import "NSString+Lookup.h"
#import "NSTextView+Autocomplete.h"
#import "MPPreferences.h"
#import "MPRenderer.h"
#import "MPPreferencesViewController.h"
#import "MPEditorPreferencesViewController.h"
#import "MPExportPanelAccessoryViewController.h"
#import "MPMathJaxListener.h"


static NSString * const kMPRendersTOCPropertyKey = @"Renders TOC";


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
                 @"automaticQuoteSubstitutionEnabled": @NO,
                 @"automaticSpellingCorrectionEnabled": @NO,
                 @"automaticTextReplacementEnabled": @NO,
                 @"continuousSpellCheckingEnabled": @NO,
                 @"enabledTextCheckingTypes": @(NSTextCheckingAllTypes),
                 @"grammarCheckingEnabled": @NO};
    });
    return keys;
}

static NSSet *MPEditorPreferencesToObserve()
{
    static NSSet *keys = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        keys = [NSSet setWithObjects:
            @"editorBaseFontInfo", @"extensionFootnotes",
            @"editorHorizontalInset", @"editorVerticalInset",
            @"editorWidthLimited", @"editorMaximumWidth", @"editorLineSpacing",
            @"editorStyleName", @"editorShowWordCount", @"editorOnRight", nil
        ];
    });
    return keys;
}

static NSString *MPAutosavePropertyKey(
    id<MPAutosaving> object, NSString *propertyName)
{
    NSString *className = NSStringFromClass([object class]);
    return [NSString stringWithFormat:@"%@ %@ %@", className, propertyName,
                                                   object.autosaveName];
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

- (CGFloat)dividerLocation
{
    NSArray *parts = self.subviews;
    NSAssert1(parts.count == 2, @"%@ should only be used on two-item splits.",
              NSStringFromSelector(_cmd));

    CGFloat totalWidth = self.frame.size.width - self.dividerThickness;
    CGFloat leftWidth = [parts[0] frame].size.width;
    return leftWidth / totalWidth;
}

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

- (NSString *)nodeText
{
    NSMutableString *text = [NSMutableString string];
    switch (self.nodeType)
    {
        case 1:
        case 9:
        case 11:
            if ([self respondsToSelector:@selector(tagName)])
            {
                NSString *tagName = [(id)self tagName];
                if ([tagName isEqualToString:@"SCRIPT"]
                        || [tagName isEqualToString:@"STYLE"])
                    break;
            }
            for (DOMNode *c = self.firstChild; c; c = c.nextSibling)
                [text appendString:c.nodeText];
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
    <NSTextViewDelegate, MPAutosaving, MPRendererDataSource, MPRendererDelegate>

typedef NS_ENUM(NSUInteger, MPWordCountType) {
    MPWordCountTypeWord,
    MPWordCountTypeCharacter,
    MPWordCountTypeCharacterNoSpaces,
};

@property (weak) IBOutlet NSSplitView *splitView;
@property (weak) IBOutlet NSView *editorContainer;
@property (unsafe_unretained) IBOutlet NSTextView *editor;
@property (weak) IBOutlet NSLayoutConstraint *editorPaddingBottom;
@property (weak) IBOutlet WebView *preview;
@property (weak) IBOutlet NSPopUpButton *wordCountWidget;
@property (copy, nonatomic) NSString *autosaveName;
@property (strong) HGMarkdownHighlighter *highlighter;
@property (strong) MPRenderer *renderer;
@property CGFloat previousSplitRatio;
@property BOOL manualRender;
@property BOOL copying;
@property BOOL printing;
@property (atomic) BOOL previewFlushDisabled;
@property BOOL shouldHandleBoundsChange;
@property (nonatomic) BOOL rendersTOC;
@property (readonly) BOOL previewVisible;
@property (readonly) BOOL editorVisible;
@property (nonatomic, readonly) BOOL needsHtml;
@property (nonatomic) NSUInteger totalWords;
@property (nonatomic) NSUInteger totalCharacters;
@property (nonatomic) NSUInteger totalCharactersNoSpaces;
@property (strong) NSMenuItem *wordsMenuItem;
@property (strong) NSMenuItem *charMenuItem;
@property (strong) NSMenuItem *charNoSpacesMenuItem;

// Store file content in initializer until nib is loaded.
@property (copy) NSString *loadedString;

- (void)syncScrollers;

@end

static void (^MPGetPreviewLoadingCompletionHandler(id obj))()
{
    __weak id weakObj = obj;
    return ^{
        [weakObj setPreviewFlushDisabled:NO];
        [weakObj syncScrollers];
    };
}


@implementation MPDocument

@synthesize previewFlushDisabled = _previewFlushDisabled;


#pragma mark - Accessor

- (MPPreferences *)preferences
{
    return [MPPreferences sharedInstance];
}

- (BOOL)previewVisible
{
    return (self.preview.frame.size.width != 0.0);
}

- (BOOL)editorVisible
{
    return (self.editorContainer.frame.size.width != 0.0);
}

- (BOOL)previewFlushDisabled
{
    @synchronized(self) {
        return _previewFlushDisabled;
    }
}

- (BOOL)needsHtml
{
    if (self.preferences.markdownManualRender)
        return NO;
    return (self.previewVisible || self.preferences.editorShowWordCount);
}

- (void)setPreviewFlushDisabled:(BOOL)value
{
    @synchronized(self) {
        if (_previewFlushDisabled == value)
            return;

        NSWindow *window = self.preview.window;
        if (value)
            [window disableFlushWindow];
        else
            [window enableFlushWindow];
        _previewFlushDisabled = value;
    }
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

- (void)setAutosaveName:(NSString *)autosaveName
{
    _autosaveName = autosaveName;
    self.splitView.autosaveName = autosaveName;
}

- (BOOL)rendersTOC
{
    NSString *key = MPAutosavePropertyKey(self, kMPRendersTOCPropertyKey);
    BOOL value = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    return value;
}

- (void)setRendersTOC:(BOOL)rendersTOC
{
    NSString *key = MPAutosavePropertyKey(self, kMPRendersTOCPropertyKey);
    [[NSUserDefaults standardUserDefaults] setBool:rendersTOC forKey:key];
}


#pragma mark - Override

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    self.shouldHandleBoundsChange = YES;
    self.previousSplitRatio = -1.0;
    return self;
}

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
    self.autosaveName = autosaveName;

    self.highlighter =
        [[HGMarkdownHighlighter alloc] initWithTextView:self.editor
                                           waitInterval:0.1];
    self.renderer = [[MPRenderer alloc] init];
    self.renderer.dataSource = self;
    self.renderer.delegate = self;

    [self setupEditor:nil];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSString *key in MPEditorPreferencesToObserve())
    {
        [defaults addObserver:self forKeyPath:key
                      options:NSKeyValueObservingOptionNew context:NULL];
    }
    for (NSString *key in MPEditorKeysToObserve())
    {
        [self.editor addObserver:self forKeyPath:key
                         options:NSKeyValueObservingOptionNew context:NULL];
    }

    self.preview.frameLoadDelegate = self;
    self.preview.policyDelegate = self;
    self.preview.editingDelegate = self;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(textDidChange:)
                   name:NSTextDidChangeNotification object:self.editor];
    [center addObserver:self selector:@selector(userDefaultsDidChange:)
                   name:NSUserDefaultsDidChangeNotification
                 object:[NSUserDefaults standardUserDefaults]];
    [center addObserver:self selector:@selector(boundsDidChange:)
                   name:NSViewBoundsDidChangeNotification
                 object:self.editor.enclosingScrollView.contentView];
    [center addObserver:self selector:@selector(didRequestEditorReload:)
                   name:MPDidRequestEditorSetupNotification object:nil];
    [center addObserver:self selector:@selector(didRequestPreviewReload:)
                   name:MPDidRequestPreviewRenderNotification object:nil];

    if (self.loadedString)
    {
        self.editor.string = self.loadedString;
        self.loadedString = nil;
        [self.renderer parseAndRenderNow];
        [self.highlighter parseAndHighlightNow];
    }

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
    [center removeObserver:self name:MPDidRequestPreviewRenderNotification
                    object:nil];
    [center removeObserver:self name:MPDidRequestEditorSetupNotification
                    object:nil];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for (NSString *key in MPEditorPreferencesToObserve())
        [defaults removeObserver:self forKeyPath:key];
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
    NSString *content = [[NSString alloc] initWithData:data
                                              encoding:NSUTF8StringEncoding];
    if (!content)
        return NO;

    self.loadedString = content;
    return YES;
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
    NSString *fileName = self.presumedFileName;
    if (fileName)
    {
        fileName = [fileName stringByAppendingPathExtension:@"md"];
        savePanel.nameFieldStringValue = fileName;
    }
    savePanel.allowedFileTypes = nil;   // Allow all extensions.
    return [super prepareSavePanel:savePanel];
}

- (NSPrintInfo *)printInfo
{
    NSPrintInfo *info = [super printInfo];
    if (!info)
        info = [[NSPrintInfo sharedPrintInfo] copy];
    info.horizontalPagination = NSAutoPagination;
    info.verticalPagination = NSAutoPagination;
    info.verticallyCentered = NO;
    info.topMargin = 0.0;
    info.leftMargin = 0.0;
    info.rightMargin = 0.0;
    info.bottomMargin = 0.0;
    return info;
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings
                                           error:(NSError *__autoreleasing *)e
{
    NSPrintInfo *info = [self.printInfo copy];
    [info.dictionary addEntriesFromDictionary:printSettings];

    WebFrameView *view = self.preview.mainFrame.frameView;
    NSPrintOperation *op = [view printOperationWithPrintInfo:info];
    return op;
}

- (void)printDocumentWithSettings:(NSDictionary *)printSettings
                   showPrintPanel:(BOOL)showPrintPanel delegate:(id)delegate
                 didPrintSelector:(SEL)selector contextInfo:(void *)contextInfo
{
    self.printing = YES;
    NSInvocation *invocation = nil;
    if (delegate && selector)
    {
        NSMethodSignature *signature =
            [NSMethodSignature methodSignatureForSelector:selector];
        invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = delegate;
        if (contextInfo)
            [invocation setArgument:&contextInfo atIndex:2];
    }
    [super printDocumentWithSettings:printSettings
                      showPrintPanel:showPrintPanel delegate:self
                    didPrintSelector:@selector(document:didPrint:context:)
                         contextInfo:(void *)invocation];
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
{
    BOOL result = [super validateUserInterfaceItem:item];
    SEL action = item.action;
    if (action == @selector(togglePreivewPane:))
    {
        NSMenuItem *it = ((NSMenuItem *)item);
        it.hidden = (!self.previewVisible && self.previousSplitRatio < 0.0);
        it.title = self.previewVisible ?
            NSLocalizedString(@"Hide Preview Pane",
                              @"Toggle preview pane menu item") :
            NSLocalizedString(@"Restore Preview Pane",
                              @"Toggle preview pane menu item");

    }
    else if (action == @selector(toggleEditorPane:))
    {
        NSMenuItem *it = (NSMenuItem*)item;
        it.title = self.editorVisible ?
        NSLocalizedString(@"Hide Editor Pane",
                          @"Toggle editor pane menu item") :
        NSLocalizedString(@"Restore Editor Pane",
                          @"Toggle editor pane menu item");
    }
    else if (action == @selector(toggleTOCRendering:))
    {
        NSInteger state = self.rendersTOC ? NSOnState : NSOffState;
        ((NSMenuItem *)item).state = state;
    }
    return result;
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
    if (textView.selectedRange.length != 0)
    {
        [self indent:nil];
        return NO;
    }
    else if (self.preferences.editorConvertTabs)
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
    if ([textView completeNextIndentedLine])
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

    // We don't want to jump rows when the line is wrapped. (#103)
    // If the line is wrapped, the target will be higher than the current glyph.
    NSLayoutManager *manager = textView.layoutManager;
    NSTextContainer *container = textView.textContainer;
    NSRect targetRect =
        [manager boundingRectForGlyphRange:NSMakeRange(location, 1)
                           inTextContainer:container];
    NSRect currentRect =
        [manager boundingRectForGlyphRange:NSMakeRange(cur, 1)
                           inTextContainer:container];
    if (targetRect.origin.y != currentRect.origin.y)
        return YES;

    textView.selectedRange = NSMakeRange(location, 0);
    return NO;
}


#pragma mark - WebFrameLoadDelegate

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
{
    if (sender.window)
        self.previewFlushDisabled = YES;

    // If MathJax is off, the on-completion callback will be invoked directly
    // when loading is done (in -webView:didFinishLoadForFrame:).
    if (self.preferences.htmlMathJax)
    {
        MPMathJaxListener *listener = [[MPMathJaxListener alloc] init];
        [listener addCallback:MPGetPreviewLoadingCompletionHandler(self)
                       forKey:@"End"];
        [sender.windowScriptObject setValue:listener forKey:@"MathJaxListener"];
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    // If MathJax is on, the on-completion callback will be invoked by the
    // JavaScript handler injected in -webView:didCommitLoadForFrame:.
    if (!self.preferences.htmlMathJax)
    {
        id callback = MPGetPreviewLoadingCompletionHandler(self);
        NSOperationQueue *queue = [NSOperationQueue mainQueue];
        [queue addOperationWithBlock:callback];
    }
    
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

        NSString *text = sender.mainFrame.DOMDocument.nodeText;
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


#pragma mark - WebEditingDelegate

- (BOOL)webView:(WebView *)webView doCommandBySelector:(SEL)selector
{
    if (selector == @selector(copy:))
    {
        NSString *html = webView.selectedDOMRange.markupString;

        // Inject the HTML content later so that it doesn't get cleared during
        // the native copy operation.
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSPasteboard *pb = [NSPasteboard generalPasteboard];
            if (![pb stringForType:@"public.html"])
                [pb setString:html forType:@"public.html"];
        }];
    }
    return NO;
}


#pragma mark - MPRendererDataSource

- (NSString *)rendererMarkdown:(MPRenderer *)renderer
{
    return self.editor.string;
}

- (NSString *)rendererHTMLTitle:(MPRenderer *)renderer
{
    NSString *n = self.fileURL.lastPathComponent.stringByDeletingPathExtension;
    return n ? n : @"";
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

- (BOOL)rendererRendersTOC:(MPRenderer *)renderer
{
    return self.rendersTOC;
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
    // Delayed copying for -copyHtml.
    if (self.copying)
    {
        self.copying = NO;
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        [pasteboard writeObjects:@[self.renderer.currentHtml]];
    }
    self.manualRender = self.preferences.markdownManualRender;
    NSURL *baseUrl = self.fileURL;
    if (!baseUrl)
        baseUrl = self.preferences.htmlDefaultDirectoryUrl;
    if (!self.printing)
        [self.preview.mainFrame loadHTMLString:html baseURL:baseUrl];
}


#pragma mark - Notification handler

- (void)textDidChange:(NSNotification *)notification
{
    if (self.needsHtml)
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
}

- (void)boundsDidChange:(NSNotification *)notification
{
    if (!self.shouldHandleBoundsChange)
        return;

    self.shouldHandleBoundsChange = NO;
    CGFloat clipWidth = [notification.object frame].size.width;
    NSRect editorFrame = self.editor.frame;
    if (editorFrame.size.width != clipWidth)
    {
        editorFrame.size.width = clipWidth;
        self.editor.frame = editorFrame;
    }
    [self syncScrollers];
    self.shouldHandleBoundsChange = YES;
}

- (void)didRequestEditorReload:(NSNotification *)notification
{
    NSString *key =
        notification.userInfo[MPDidRequestEditorSetupNotificationKeyName];
    [self setupEditor:key];
}

- (void)didRequestPreviewReload:(NSNotification *)notification
{
    [self render:nil];
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
    else if (object == [NSUserDefaults standardUserDefaults])
    {
        if (self.highlighter.isActive)
            [self setupEditor:keyPath];
    }
}


#pragma mark - IBAction

- (IBAction)copyHtml:(id)sender
{
    // Dis-select things in WebView so that it's more obvious we're NOT
    // respecting the selection range.
    [self.preview setSelectedDOMRange:nil affinity:NSSelectionAffinityUpstream];

    // If the preview is hidden, the HTML are not updating on text change.
    // Perform one extra rendering so that the HTML is up to date, and do the
    // copy in the rendering callback.
    if (!self.needsHtml)
    {
        self.copying = YES;
        [self.renderer parseAndRenderNow];
        return;
    }
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard writeObjects:@[self.renderer.currentHtml]];
}

- (IBAction)exportHtml:(id)sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedFileTypes = @[@"html"];
    if (self.presumedFileName)
        panel.nameFieldStringValue = self.presumedFileName;

    MPExportPanelAccessoryViewController *controller =
        [[MPExportPanelAccessoryViewController alloc] init];
    controller.stylesIncluded = (BOOL)self.preferences.htmlStyleName;
    controller.highlightingIncluded = self.preferences.htmlSyntaxHighlighting;
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

- (IBAction)exportPdf:(id)sender
{
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedFileTypes = @[@"pdf"];
    if (self.presumedFileName)
        panel.nameFieldStringValue = self.presumedFileName;
    
    NSWindow *w = nil;
    NSArray *windowControllers = self.windowControllers;
    if (windowControllers.count > 0)
        w = [windowControllers[0] window];

    [panel beginSheetModalForWindow:w completionHandler:^(NSInteger result) {
        if (result != NSFileHandlingPanelOKButton)
            return;
        NSPrintInfo *info = self.printInfo;
        [info.dictionary addEntriesFromDictionary:@{
            NSPrintJobDisposition: NSPrintSaveJob,
            NSPrintJobSavingURL: panel.URL
        }];
        NSView *view = self.preview.mainFrame.frameView.documentView;
        NSPrintOperation *op = [NSPrintOperation printOperationWithView:view
                                                              printInfo:info];
        op.showsPrintPanel = NO;
        op.showsProgressPanel = NO;
        [op runOperation];
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

- (IBAction)togglePreivewPane:(id)sender
{
    if (self.previewVisible)
    {
        self.previousSplitRatio = self.splitView.dividerLocation;
        BOOL editorOnRight = self.preferences.editorOnRight;
        [self setSplitViewDividerLocation:(editorOnRight ? 0.0 : 1.0)];
    }
    else
    {
        if (self.previousSplitRatio >= 0.0)
            [self setSplitViewDividerLocation:self.previousSplitRatio];
    }
}

- (IBAction)toggleEditorPane:(id)sender
{
    if (self.editorVisible)
    {
        self.previousSplitRatio = self.splitView.dividerLocation;
        if (self.preferences.editorOnRight)
            [self setSplitViewDividerLocation:1.0];
        else
            [self setSplitViewDividerLocation:0.0];
    }
    else
    {
        if (self.previousSplitRatio >= 0.0)
            [self setSplitViewDividerLocation:self.previousSplitRatio];
    }
}

- (IBAction)render:(id)sender
{
    [self.renderer parseAndRenderLater];
}

- (IBAction)toggleTOCRendering:(id)sender
{
    BOOL nextState = NO;
    if ([sender state] == NSOffState)
        nextState = YES;
    self.rendersTOC = nextState;
}


#pragma mark - Private

- (void)setupEditor:(NSString *)changedKey
{
    [self.highlighter deactivate];

    if (!changedKey || [changedKey isEqualToString:@"extensionFootnotes"])
    {
        int extensions = pmh_EXT_NOTES;
        if (self.preferences.extensionFootnotes)
            extensions = pmh_EXT_NONE;
        self.highlighter.extensions = extensions;
    }

    if (!changedKey || [changedKey isEqualToString:@"editorHorizontalInset"]
            || [changedKey isEqualToString:@"editorVerticalInset"]
            || [changedKey isEqualToString:@"editorWidthLimited"]
            || [changedKey isEqualToString:@"editorMaximumWidth"])
    {
        CGFloat x = self.preferences.editorHorizontalInset;
        CGFloat y = self.preferences.editorVerticalInset;
        if (self.preferences.editorWidthLimited)
        {
            CGFloat editorWidth = self.editor.frame.size.width;
            CGFloat maxWidth = self.preferences.editorMaximumWidth;
            if (editorWidth > 2 * x + maxWidth)
                x = (editorWidth - maxWidth) * 0.45;
            // We tend to expect things in an editor to shift to left a bit.
            // Hence the 0.45 instead of 0.5 (which whould feel a bit too much).
        }
        self.editor.textContainerInset = NSMakeSize(x, y);
    }

    if (!changedKey || [changedKey isEqualToString:@"editorBaseFontInfo"]
            || [changedKey isEqualToString:@"editorStyleName"]
            || [changedKey isEqualToString:@"editorLineSpacing"])
    {
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineSpacing = self.preferences.editorLineSpacing;
        self.editor.defaultParagraphStyle = [style copy];
        self.editor.font = [self.preferences.editorBaseFont copy];
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

        CGColorRef backgroundCGColor = self.editor.backgroundColor.CGColor;

        CALayer *layer = [CALayer layer];
        layer.backgroundColor = backgroundCGColor;
        self.editorContainer.layer = layer;
        self.editorContainer.wantsLayer = YES;

        layer = [CALayer layer];
        layer.backgroundColor = backgroundCGColor;
        self.splitView.layer = layer;
        self.splitView.wantsLayer = YES;
    }

    if (!changedKey || [changedKey isEqualToString:@"editorShowWordCount"])
    {
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
    }

    if (!changedKey)
    {
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
    }

    if (!changedKey || [changedKey isEqualToString:@"editorOnRight"])
    {
        BOOL editorOnRight = self.preferences.editorOnRight;
        NSArray *subviews = self.splitView.subviews;
        if ((!editorOnRight && subviews[0] == self.preview)
            || (editorOnRight && subviews[1] == self.preview))
        {
            [self.splitView swapViews];
            if (!self.previewVisible && self.previousSplitRatio >= 0.0)
                self.previousSplitRatio = 1.0 - self.previousSplitRatio;

            // Need to queue this or the views won't be initialised correctly.
            // Don't really know why, but this works.
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.splitView.needsLayout = YES;
            }];
        }
    }

    [self.highlighter activate];
    self.editor.automaticLinkDetectionEnabled = NO;
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
    [self setupEditor:NSStringFromSelector(@selector(editorHorizontalInset))];
}

- (NSString *)presumedFileName
{
    if (self.fileURL)
        return self.fileURL.lastPathComponent.stringByDeletingPathExtension;

    NSString *title = nil;
    NSString *string = self.editor.string;
    if (self.preferences.htmlDetectFrontMatter)
        title = [[[string frontMatter:NULL] objectForKey:@"title"] description];
    if (title)
        return title;

    title = string.titleString;
    if (!title)
        return nil;

    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"[/|:]"
                                                          options:0 error:NULL];
    });

    NSRange range = NSMakeRange(0, title.length);
    title = [regex stringByReplacingMatchesInString:title options:0 range:range
                                       withTemplate:@"-"];
    return title;
}

- (void)document:(NSDocument *)doc didPrint:(BOOL)ok context:(void *)context
{
    if ([doc respondsToSelector:@selector(setPrinting:)])
        [(id)doc setPrinting:NO];
    if (context)
    {
        NSInvocation *invocation = (__bridge NSInvocation *)context;
        if ([invocation isKindOfClass:[NSInvocation class]])
        {
            [invocation setArgument:&doc atIndex:0];
            [invocation setArgument:&ok atIndex:1];
            [invocation invoke];
        }
    }
}

@end
