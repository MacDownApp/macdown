//
//  MPDocument.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 6/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//
//  Portions Copyright (c) 2026 Roberto Bissanti.
//

#import "MPDocument.h"
#import <WebKit/WebKit.h>
// UTType, used in -urlIsBlockedExecutable: (see CVE-2019-12138 /
// CVE-2019-12173 fix below).
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <JJPluralForm/JJPluralForm.h>
#import <hoedown/html.h>
#import "hoedown_html_patch.h"
#import "HGMarkdownHighlighter.h"
#import "MPUtilities.h"
#import "MPAutosaving.h"
#import "NSColor+HTML.h"
#import "NSDocumentController+Document.h"
#import "NSPasteboard+Types.h"
#import "NSString+Lookup.h"
#import "NSTextView+Autocomplete.h"
#import "MPPreferences.h"
#import "MPDocumentSplitView.h"
#import "MPEditorView.h"
#import "MPRenderer.h"
#import "MPPreferencesViewController.h"
#import "MPEditorPreferencesViewController.h"
#import "MPExportPanelAccessoryViewController.h"
#import "MPToolbarController.h"

static NSString * const kMPDefaultAutosaveName = @"Untitled";


NS_INLINE NSString *MPEditorPreferenceKeyWithValueKey(NSString *key)
{
    if (!key.length)
        return @"editor";
    NSString *first = [[key substringToIndex:1] uppercaseString];
    NSString *rest = [key substringFromIndex:1];
    return [NSString stringWithFormat:@"editor%@%@", first, rest];
}

NS_INLINE NSDictionary *MPEditorKeysToObserve(void)
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

NS_INLINE NSSet *MPEditorPreferencesToObserve(void)
{
    static NSSet *keys = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        keys = [NSSet setWithObjects:
            @"editorBaseFontInfo", @"extensionFootnotes",
            @"editorHorizontalInset", @"editorVerticalInset",
            @"editorWidthLimited", @"editorMaximumWidth", @"editorLineSpacing",
            @"editorOnRight", @"editorStyleName", @"editorShowWordCount",
            @"editorScrollsPastEnd", nil
        ];
    });
    return keys;
}

NS_INLINE NSString *MPRectStringForAutosaveName(NSString *name)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *key = [NSString stringWithFormat:@"NSWindow Frame %@", name];
    NSString *rectString = [defaults objectForKey:key];
    return rectString;
}

@implementation NSURL (Convert)

- (NSString *)absoluteBaseURLString
{
    // Remove fragment (#anchor) and query string.
    NSString *base = self.absoluteString;
    base = [base componentsSeparatedByString:@"?"].firstObject;
    base = [base componentsSeparatedByString:@"#"].firstObject;
    return base;
}

@end


@implementation MPPreferences (Hoedown)
- (int)extensionFlags
{
    int flags = 0;
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
    if (self.htmlMathJax)
        flags |= HOEDOWN_EXT_MATH;
    if (self.htmlMathJaxInlineDollar)
        flags |= HOEDOWN_EXT_MATH_EXPLICIT;
    return flags;
}

- (int)rendererFlags
{
    int flags = 0;
    if (self.htmlTaskList)
        flags |= HOEDOWN_HTML_USE_TASK_LIST;
    if (self.htmlLineNumbers)
        flags |= HOEDOWN_HTML_BLOCKCODE_LINE_NUMBERS;
    if (self.htmlHardWrap)
        flags |= HOEDOWN_HTML_HARD_WRAP;
    if (self.htmlCodeBlockAccessory == MPCodeBlockAccessoryCustom)
        flags |= HOEDOWN_HTML_BLOCKCODE_INFORMATION;
    return flags;
}
@end


@interface MPDocument ()
    <NSSplitViewDelegate, NSTextViewDelegate,
     WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler,
     MPAutosaving, MPRendererDataSource, MPRendererDelegate>

typedef NS_ENUM(NSUInteger, MPWordCountType) {
    MPWordCountTypeWord,
    MPWordCountTypeCharacter,
    MPWordCountTypeCharacterNoSpaces,
};

@property (weak) IBOutlet NSToolbar *toolbar;
@property (weak) IBOutlet MPDocumentSplitView *splitView;
@property (weak) IBOutlet NSView *editorContainer;
// unsafe_unretained here (unlike every sibling IBOutlet above, all `weak`)
// dates back to the original 2014 project setup, predating this codebase's
// adoption of `weak` IBOutlets, and was never updated. A raw, non-zeroing
// pointer means that if the underlying MPEditorView is ever deallocated
// and recreated (e.g. during window/layout churn), `editor` keeps pointing
// at freed memory -- any later message to it (toggleForMarkupPrefix:suffix:,
// .selectedRange, .string, ...) is then a dangling-pointer access, i.e.
// EXC_BAD_ACCESS. `weak` makes the pointer nil itself out instead of
// dangling, turning a crash into a safe no-op.
@property (weak) IBOutlet MPEditorView *editor;
@property (weak) IBOutlet NSLayoutConstraint *editorPaddingBottom;
// Instantiated programmatically in -windowControllerDidLoadNib: and swapped
// into the split view in place of a plain NSView placeholder (see
// MPDocument.xib). This lets us attach a WKWebViewConfiguration with script
// message handlers before any content is loaded, which Interface Builder's
// nib-based WKWebView instantiation doesn't allow.
@property (weak) IBOutlet WKWebView *preview;
@property (weak) IBOutlet NSPopUpButton *wordCountWidget;
@property (strong) IBOutlet MPToolbarController *toolbarController;
@property (copy, nonatomic) NSString *autosaveName;
@property (strong) HGMarkdownHighlighter *highlighter;
@property (strong) MPRenderer *renderer;
@property CGFloat previousSplitRatio;
@property BOOL manualRender;
@property BOOL copying;
@property BOOL printing;
@property BOOL shouldHandleBoundsChange;
@property BOOL isPreviewReady;
@property (strong) NSURL *currentBaseUrl;
// A per-document, stable-but-unique sidecar HTML file we render the preview
// into (see -renderer:didProduceHTMLOutput:), written next to the source
// document so relative asset paths keep resolving exactly as before.
@property (strong) NSURL *previewTempFileUrl;
@property CGFloat lastPreviewScrollTop;
@property (nonatomic, readonly) BOOL needsHtml;
@property (nonatomic) NSUInteger totalWords;
@property (nonatomic) NSUInteger totalCharacters;
@property (nonatomic) NSUInteger totalCharactersNoSpaces;
@property (strong) NSMenuItem *wordsMenuItem;
@property (strong) NSMenuItem *charMenuItem;
@property (strong) NSMenuItem *charNoSpacesMenuItem;
@property (nonatomic) BOOL needsToUnregister;
@property (nonatomic) BOOL alreadyRenderingInWeb;
@property (nonatomic) BOOL renderToWebPending;
@property (strong) NSArray<NSNumber *> *webViewHeaderLocations;
@property (strong) NSArray<NSNumber *> *editorHeaderLocations;
@property (nonatomic) BOOL inLiveScroll;
// Cached values fetched asynchronously from the preview's JS context, since
// WKWebView (unlike the legacy WebView) exposes no synchronous DOM/JS access.
@property CGFloat cachedPreviewContentHeight;
@property (strong) NSColor *cachedPreviewBackgroundColor;

// Store file content in initializer until nib is loaded.
@property (copy) NSString *loadedString;

- (void)scaleWebview;
- (void)syncScrollers;
- (void)updateHeaderLocationsWithCompletion:(void (^)(void))completion;

@end


@implementation MPDocument

#pragma mark - Accessor

- (MPPreferences *)preferences
{
    return [MPPreferences sharedInstance];
}

- (NSString *)markdown
{
    return self.editor.string;
}

- (void)setMarkdown:(NSString *)markdown
{
    self.editor.string = markdown;
}

- (NSString *)html
{
    return self.renderer.currentHtml;
}

- (BOOL)toolbarVisible
{
    return self.windowForSheet.toolbar.visible;
}

- (BOOL)previewVisible
{
    return (self.preview.frame.size.width != 0.0);
}

- (BOOL)editorVisible
{
    return (self.editorContainer.frame.size.width != 0.0);
}

- (BOOL)needsHtml
{
    if (self.preferences.markdownManualRender)
        return NO;
    return (self.previewVisible || self.preferences.editorShowWordCount);
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


#pragma mark - Override

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    self.isPreviewReady = NO;
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

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // All files use their absolute path to keep their window states.
    NSString *autosaveName = kMPDefaultAutosaveName;
    if (self.fileURL)
        autosaveName = self.fileURL.absoluteString;
    controller.window.frameAutosaveName = autosaveName;
    self.autosaveName = autosaveName;

    // Perform initial resizing manually because for some reason untitled
    // documents do not pick up the autosaved frame automatically in 10.10.
    NSString *rectString = MPRectStringForAutosaveName(autosaveName);
    if (!rectString)
        rectString = MPRectStringForAutosaveName(kMPDefaultAutosaveName);
    if (rectString)
        [controller.window setFrameFromString:rectString];

    self.highlighter =
        [[HGMarkdownHighlighter alloc] initWithTextView:self.editor
                                           waitInterval:0.0];
    self.renderer = [[MPRenderer alloc] init];
    self.renderer.dataSource = self;
    self.renderer.delegate = self;

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

    self.editor.postsFrameChangedNotifications = YES;

    // The preview pane is a plain NSView placeholder in the nib (see
    // MPDocument.xib). We create the real WKWebView here instead of via
    // Interface Builder so we can attach a WKWebViewConfiguration with
    // script message handlers (used for MathJax completion and preview
    // scroll tracking) before any content is ever loaded into it.
    NSView *previewPlaceholder = (NSView *)self.preview;
    WKUserContentController *userContentController =
        [[WKUserContentController alloc] init];
    [userContentController addScriptMessageHandler:self name:@"mathJaxListener"];
    [userContentController addScriptMessageHandler:self name:@"previewScroll"];
    NSString *scrollListenerSource =
        @"window.addEventListener('scroll', function () {"
        @"    window.webkit.messageHandlers.previewScroll.postMessage(window.scrollY);"
        @"}, { passive: true });";
    WKUserScript *scrollListenerScript =
        [[WKUserScript alloc] initWithSource:scrollListenerSource
                                injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                             forMainFrameOnly:YES];
    [userContentController addUserScript:scrollListenerScript];

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.userContentController = userContentController;

    WKWebView *webView = [[WKWebView alloc] initWithFrame:previewPlaceholder.frame
                                              configuration:configuration];
    webView.translatesAutoresizingMaskIntoConstraints =
        previewPlaceholder.translatesAutoresizingMaskIntoConstraints;
    webView.autoresizingMask = previewPlaceholder.autoresizingMask;
    webView.navigationDelegate = self;
    webView.UIDelegate = self;
    [self.splitView replaceSubview:previewPlaceholder with:webView];
    self.preview = webView;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(editorTextDidChange:)
                   name:NSTextDidChangeNotification object:self.editor];
    [center addObserver:self selector:@selector(userDefaultsDidChange:)
                   name:NSUserDefaultsDidChangeNotification
                 object:[NSUserDefaults standardUserDefaults]];
    [center addObserver:self selector:@selector(editorBoundsDidChange:)
                   name:NSViewBoundsDidChangeNotification
                 object:self.editor.enclosingScrollView.contentView];
    [center addObserver:self selector:@selector(editorFrameDidChange:)
                   name:NSViewFrameDidChangeNotification object:self.editor];
    [center addObserver:self selector:@selector(didRequestEditorReload:)
                   name:MPDidRequestEditorSetupNotification object:nil];
    [center addObserver:self selector:@selector(didRequestPreviewReload:)
                   name:MPDidRequestPreviewRenderNotification object:nil];
    [center addObserver:self selector:@selector(willStartLiveScroll:)
                   name:NSScrollViewWillStartLiveScrollNotification
                 object:self.editor.enclosingScrollView];
    [center addObserver:self selector:@selector(didEndLiveScroll:)
                   name:NSScrollViewDidEndLiveScrollNotification
                 object:self.editor.enclosingScrollView];
    // Preview scroll position is now tracked via the "previewScroll" script
    // message handler (see -userContentController:didReceiveScriptMessage:)
    // instead of an NSScrollView notification, since WKWebView exposes no
    // public NSScrollView on macOS.

    self.needsToUnregister = YES;

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
    wordCountWidget.enabled = NO;

    // These needs to be queued until after the window is shown, so that editor
    // can have the correct dimention for size-limiting and stuff. See
    // https://github.com/uranusjr/macdown/issues/236
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self setupEditor:nil];
        [self redrawDivider];
        [self reloadFromLoadedString];
    }];
}

- (void)reloadFromLoadedString
{
    if (self.loadedString && self.editor && self.renderer && self.highlighter)
    {
        self.editor.string = self.loadedString;
        self.loadedString = nil;
        [self.renderer parseAndRenderNow];
        [self.highlighter parseAndHighlightNow];
    }
}

- (void)close
{
    if (self.needsToUnregister) 
    {
        // Close can be called multiple times, but this can only be done once.
        // http://www.cocoabuilder.com/archive/cocoa/240166-nsdocument-close-method-calls-itself.html
        self.needsToUnregister = NO;

        // Need to cleanup these so that callbacks won't crash the app.
        [self.highlighter deactivate];
        self.highlighter.targetTextView = nil;
        self.highlighter = nil;
        self.renderer = nil;
        self.preview.navigationDelegate = nil;
        self.preview.UIDelegate = nil;
        // WKUserContentController retains its script message handlers
        // strongly, which would otherwise keep this document alive forever
        // via preview -> configuration -> userContentController -> self.
        [self.preview.configuration.userContentController
            removeScriptMessageHandlerForName:@"mathJaxListener"];
        [self.preview.configuration.userContentController
            removeScriptMessageHandlerForName:@"previewScroll"];

        if (self.previewTempFileUrl)
        {
            [[NSFileManager defaultManager]
                removeItemAtURL:self.previewTempFileUrl error:NULL];
            self.previewTempFileUrl = nil;
        }

        [[NSNotificationCenter defaultCenter] removeObserver:self];

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        for (NSString *key in MPEditorPreferencesToObserve())
            [defaults removeObserver:self forKeyPath:key];
        for (NSString *key in MPEditorKeysToObserve())
            [self.editor removeObserver:self forKeyPath:key];
    }

    [super close];
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

+ (NSArray *)writableTypes
{
    return @[@"net.daringfireball.markdown"];
}

- (BOOL)isDocumentEdited
{
    // Prevent save dialog on an unnamed, empty document. The file will still
    // show as modified (because it is), but no save dialog will be presented
    // when the user closes it.
    if (!self.presentedItemURL && !self.editor.string.length)
        return NO;
    return [super isDocumentEdited];
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName
             error:(NSError *__autoreleasing *)outError
{
    if (self.preferences.editorEnsuresNewlineAtEndOfFile)
    {
        NSCharacterSet *newline = [NSCharacterSet newlineCharacterSet];
        NSString *text = self.editor.string;
        NSUInteger end = text.length;
        if (end && ![newline characterIsMember:[text characterAtIndex:end - 1]])
        {
            NSRange selection = self.editor.selectedRange;
            [self.editor insertText:@"\n" replacementRange:NSMakeRange(end, 0)];
            self.editor.selectedRange = selection;
        }
    }
    return [super writeToURL:url ofType:typeName error:outError];
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
    [self reloadFromLoadedString];
    return YES;
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
    savePanel.extensionHidden = NO;
    if (self.fileURL && self.fileURL.isFileURL)
    {
        NSString *path = self.fileURL.path;

        // Use path of parent directory if this is a file. Otherwise this is it.
        BOOL isDir = NO;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path
                                                           isDirectory:&isDir];
        if (!exists || !isDir)
            path = [path stringByDeletingLastPathComponent];

        savePanel.directoryURL = [NSURL fileURLWithPath:path];
    }
    else
    {
        // Suggest a file name for new documents.
        NSString *fileName = self.presumedFileName;
        if (fileName && ![fileName hasExtension:@"md"])
        {
            fileName = [fileName stringByAppendingPathExtension:@"md"];
            savePanel.nameFieldStringValue = fileName;
        }
    }
    
    // Get supported extensions from plist
    static NSMutableArray *supportedExtensions = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        supportedExtensions = [NSMutableArray array];
        NSDictionary *infoDict = [NSBundle mainBundle].infoDictionary;
        for (NSDictionary *docType in infoDict[@"CFBundleDocumentTypes"])
        {
            NSArray *exts = docType[@"CFBundleTypeExtensions"];
            if (exts.count)
            {
                [supportedExtensions addObjectsFromArray:exts];
            }
        }
    });
    
    // allowedFileTypes takes extension strings; the macOS 12+ replacement,
    // allowedContentTypes, wants UTType objects instead. Map each extension
    // through +[UTType typeWithFilenameExtension:], dropping any that don't
    // resolve to a known type.
    NSMutableArray<UTType *> *supportedTypes =
        [NSMutableArray arrayWithCapacity:supportedExtensions.count];
    for (NSString *extension in supportedExtensions)
    {
        UTType *type = [UTType typeWithFilenameExtension:extension];
        if (type)
            [supportedTypes addObject:type];
    }
    savePanel.allowedContentTypes = supportedTypes;
    savePanel.allowsOtherFileTypes = YES; // Allow all extensions.
    
    return [super prepareSavePanel:savePanel];
}

- (NSPrintInfo *)printInfo
{
    NSPrintInfo *info = [super printInfo];
    if (!info)
        info = [[NSPrintInfo sharedPrintInfo] copy];
    // NSAutoPagination itself is flagged deprecated (macOS 11), but unlike
    // the other warnings in this file Apple's compiler note gives no
    // replacement API/constant to migrate to -- horizontalPagination/
    // verticalPagination still only accept NSPrintingPaginationMode values,
    // and NSAutoPagination is still the correct one to request. Silencing
    // just these two lines rather than guessing at a nonexistent successor.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    info.horizontalPagination = NSAutoPagination;
    info.verticalPagination = NSAutoPagination;
#pragma clang diagnostic pop
    info.verticallyCentered = NO;
    info.topMargin = 50.0;
    info.leftMargin = 0.0;
    info.rightMargin = 0.0;
    info.bottomMargin = 50.0;
    return info;
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings
                                           error:(NSError *__autoreleasing *)e
{
    NSPrintInfo *info = [self.printInfo copy];
    [info.dictionary addEntriesFromDictionary:printSettings];

    // WKWebView.printOperationWithPrintInfo: is public API since macOS 11;
    // it's the only way to plug a web view into NSDocument's synchronous
    // printOperationWithSettings:error: contract (the async replacement,
    // -createPDFWithConfiguration:completionHandler:, doesn't fit this call
    // site). Known limitation carried over from upstream WebKit: content
    // scrolled out of view may not print.
    //
    // Undocumented but load-bearing gotcha (see
    // https://developer.apple.com/forums/thread/705138): the returned
    // operation's view has no frame set, and running it as-is crashes.
    // It must be explicitly sized to the paper before NSDocument's own
    // printing machinery (our caller's superclass) runs it.
    NSPrintOperation *op = [self.preview printOperationWithPrintInfo:info];
    op.view.frame = NSMakeRect(0, 0,
                                info.paperSize.width, info.paperSize.height);
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
    if (action == @selector(toggleToolbar:))
    {
        NSMenuItem *it = ((NSMenuItem *)item);
        it.title = self.toolbarVisible ?
            NSLocalizedString(@"Hide Toolbar",
                              @"Toggle reveal toolbar") :
            NSLocalizedString(@"Show Toolbar",
                              @"Toggle reveal toolbar");
    }
    else if (action == @selector(togglePreviewPane:))
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
    return result;
}


#pragma mark - NSSplitViewDelegate

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
    [self redrawDivider];
    self.editor.editable = self.editorVisible;
}


#pragma mark - NSTextViewDelegate

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertTab:))
        return ![self textViewShouldInsertTab:textView];
    else if (commandSelector == @selector(insertBacktab:))
        return ![self textViewShouldInsertBacktab:textView];
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
    
	// For every change, set the typing attributes
	if (range.location > 0) {
		NSRange prevRange = range;
		prevRange.location -= 1;
		prevRange.length = 1;

		NSDictionary *attr = [[textView attributedString] fontAttributesInRange:prevRange];
		[textView setTypingAttributes:attr];
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

- (BOOL)textViewShouldInsertBacktab:(NSTextView *)textView
{
    [self unindent:nil];
    return NO;
}

- (BOOL)textViewShouldInsertNewline:(NSTextView *)textView
{
    if ([textView insertMappedContent])
        return NO;

    BOOL inserts = self.preferences.editorInsertPrefixInBlock;
    if (inserts && [textView completeNextListItem:
            self.preferences.editorAutoIncrementNumberedLists])
        return NO;
    if (inserts && [textView completeNextBlockquoteLine])
        return NO;
    if ([textView completeNextIndentedLine])
        return NO;
    return YES;
}

- (BOOL)textViewShouldDeleteBackward:(NSTextView *)textView
{
    NSRange selectedRange = textView.selectedRange;
    if (self.preferences.editorCompleteMatchingCharacters)
    {
        NSUInteger location = selectedRange.location;
        if ([textView deleteMatchingCharactersAround:location])
            return NO;
    }
    if (self.preferences.editorConvertTabs && !selectedRange.length)
    {
        NSUInteger location = selectedRange.location;
        if ([textView unindentForSpacesBefore:location])
            return NO;
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
    if (location == cur || cur == 0)
        return YES;
    else if (cur >= textView.string.length)
        cur = textView.string.length - 1;

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


#pragma mark - Preview load completion

// Shared tail-end of a preview reload: rescale for the editor's font size,
// and either re-sync scroll position with the editor or restore the
// previously-remembered preview scroll offset. Called directly from
// -webView:didFinishNavigation: when MathJax is off, or from the
// "mathJaxListener" script message once MathJax has finished typesetting
// (equation rendering can noticeably shift the layout, so we wait for it).
- (void)previewDidFinishLoadingContent
{
    [self scaleWebview];
    if (self.preferences.editorSyncScrolling)
    {
        __weak typeof(self) weakSelf = self;
        [self updateHeaderLocationsWithCompletion:^{
            [weakSelf syncScrollers];
        }];
    }
    else
    {
        NSString *js = [NSString stringWithFormat:
            @"window.scrollTo(0, %f);", self.lastPreviewScrollTop];
        [self.preview evaluateJavaScript:js completionHandler:nil];
    }
    [self updatePreviewBackgroundColorCache];
}

- (void)handlePreviewLoadFinishOrFailure
{
    if (!self.preferences.htmlMathJax)
    {
        __weak typeof(self) weakSelf = self;
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [weakSelf previewDidFinishLoadingContent];
        }];
    }
    // If MathJax is on, previewDidFinishLoadingContent is instead invoked by
    // the "mathJaxListener" script message once MathJax finishes.

    self.isPreviewReady = YES;

    if (self.preferences.editorShowWordCount)
        [self updateWordCount];

    self.alreadyRenderingInWeb = NO;

    if (self.renderToWebPending)
        [self.renderer parseAndRenderNow];

    self.renderToWebPending = NO;
}


#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self handlePreviewLoadFinishOrFailure];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation
       withError:(NSError *)error
{
    [self handlePreviewLoadFinishOrFailure];
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                        withError:(NSError *)error
{
    [self handlePreviewLoadFinishOrFailure];
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *url = navigationAction.request.URL;
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated)
    {
        // If the target is exactly as the current one, ignore.
        if ([self.currentBaseUrl isEqual:url])
        {
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
        // If this is a different page, intercept and handle ourselves.
        if (![self isCurrentBaseUrl:url])
        {
            decisionHandler(WKNavigationActionPolicyCancel);
            [self openOrCreateFileForUrl:url];
            return;
        }
        // Otherwise this is somewhere else on the same page. Let it jump there.
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}


#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
       didReceiveScriptMessage:(WKScriptMessage *)message
{
    if ([message.name isEqualToString:@"mathJaxListener"])
    {
        [self previewDidFinishLoadingContent];
    }
    else if ([message.name isEqualToString:@"previewScroll"])
    {
        if ([message.body isKindOfClass:[NSNumber class]])
            self.lastPreviewScrollTop = [(NSNumber *)message.body doubleValue];
    }
}


#pragma mark - WKUIDelegate

// Note: WKUIDelegate has no equivalent to the legacy WebUIDelegate's
// -webView:dragDestinationActionMaskForDraggingInfo:, which disabled drag
// destination actions on the preview. WKWebView's default drag handling is
// used instead; verify dropping a file onto the preview pane behaves
// reasonably.

#pragma mark - MPRendererDataSource

- (BOOL)rendererLoading {
	return self.preview.loading;
}
    
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
    return self.preferences.htmlRendersTOC;
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

- (BOOL)rendererHasMermaid:(MPRenderer *)renderer
{
    return self.preferences.htmlMermaid;
}

- (BOOL)rendererHasGraphviz:(MPRenderer *)renderer
{
    return self.preferences.htmlGraphviz;
}

- (MPCodeBlockAccessoryType)rendererCodeBlockAccesory:(MPRenderer *)renderer
{
    return self.preferences.htmlCodeBlockAccessory;
}

- (BOOL)rendererHasMathJax:(MPRenderer *)renderer
{
    return self.preferences.htmlMathJax;
}

- (NSString *)rendererHighlightingThemeName:(MPRenderer *)renderer
{
    return self.preferences.htmlHighlightingThemeName;
}

- (void)renderer:(MPRenderer *)renderer didProduceHTMLOutput:(NSString *)html
{
    if (self.alreadyRenderingInWeb)
    {
        self.renderToWebPending = YES;
        return;
    }
    
    if (self.printing)
        return;
    
    self.alreadyRenderingInWeb = YES;

    // Delayed copying for -copyHtml.
    if (self.copying)
    {
        self.copying = NO;
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        [pasteboard writeObjects:@[self.renderer.currentHtml]];
    }

    NSURL *baseUrl = self.fileURL;
    if (!baseUrl)   // Unsaved doument; just use the default URL.
        baseUrl = self.preferences.htmlDefaultDirectoryUrl;

    self.manualRender = self.preferences.markdownManualRender;

    // A previous in-place DOM-patching optimization (replace just the
    // <html> tag's innerHTML instead of reloading) was abandoned upstream
    // long before this migration: it broke MathJax and Prism re-rendering,
    // since essentially all page JavaScript needs to run again after a DOM
    // replacement. A full reload is simpler and is what was actually in
    // effect (the optimized path was already dead code, disabled via
    // "#if 0").
    //
    // We used to call -loadHTMLString:baseURL:, which exists identically on
    // WKWebView -- but unlike the legacy WebView, WKWebView restricts
    // file:// sub-resource loads under it to baseURL's own directory tree.
    // Local stylesheet/script assets are now embedded inline by MPRenderer
    // to route around that (see -[MPRenderer render]), but that trick
    // doesn't apply to <img> references the user's own Markdown points at,
    // which can be an absolute path anywhere on disk (e.g. ~/Downloads) --
    // those still need a real file:// load to succeed. So instead we write
    // the rendered HTML to a sidecar file next to the source document (same
    // directory, so relative asset paths still resolve exactly as before)
    // and load that via -loadFileURL:allowingReadAccessToURL:, which lets
    // us explicitly grant broader read access. We grant access to "/"
    // rather than trying to enumerate every directory a Markdown file might
    // reference an image from (Desktop, Downloads, a Photos export, a
    // network volume, ...); this merely restores WebView1's old behavior,
    // which never sandboxed local file access in the first place.
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL baseUrlIsDirectory = NO;
    [manager fileExistsAtPath:baseUrl.path isDirectory:&baseUrlIsDirectory];
    NSURL *baseDirectory =
        baseUrlIsDirectory ? baseUrl : baseUrl.URLByDeletingLastPathComponent;

    // If the document moved (Save As, rename) since we last created the
    // sidecar file, its directory no longer matches baseDirectory -- drop
    // the stale one so relative asset paths keep resolving against the
    // document's *current* location instead of a stale unrelated folder.
    if (self.previewTempFileUrl &&
        ![self.previewTempFileUrl.URLByDeletingLastPathComponent
            isEqual:baseDirectory])
    {
        [manager removeItemAtURL:self.previewTempFileUrl error:NULL];
        self.previewTempFileUrl = nil;
    }

    if (!self.previewTempFileUrl)
    {
        NSString *name =
            [NSString stringWithFormat:@".macdown-preview-%@.html",
                                        [NSUUID UUID].UUIDString];
        self.previewTempFileUrl =
            [baseDirectory URLByAppendingPathComponent:name];
    }

    NSError *writeError = nil;
    BOOL wrote = [html writeToURL:self.previewTempFileUrl
                        atomically:YES
                          encoding:NSUTF8StringEncoding
                             error:&writeError];
    if (wrote)
    {
        [self.preview loadFileURL:self.previewTempFileUrl
           allowingReadAccessToURL:[NSURL fileURLWithPath:@"/"]];
        // -isCurrentBaseUrl: (used by -decidePolicyForNavigationAction: to
        // tell an in-page anchor jump from a link to a different file) needs
        // to compare against whatever WKWebView actually thinks its current
        // page URL is, which after -loadFileURL: is previewTempFileUrl, not
        // the document's own path.
        self.currentBaseUrl = self.previewTempFileUrl;
    }
    else
    {
        // Directory isn't writable (read-only volume, external drive
        // mounted read-only, etc.) -- fall back to the old behavior rather
        // than showing a blank preview. Cross-directory local images will
        // still fail to load in this fallback, same as before this fix.
        self.previewTempFileUrl = nil;
        [self.preview loadHTMLString:html baseURL:baseUrl];
        self.currentBaseUrl = baseUrl;
    }
}


#pragma mark - Notification handler

- (void)editorTextDidChange:(NSNotification *)notification
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
        [renderer parseIfPreferencesChanged];
        [renderer renderIfPreferencesChanged];
    }
}

- (void)editorFrameDidChange:(NSNotification *)notification
{
    if (self.preferences.editorWidthLimited)
        [self adjustEditorInsets];
}

- (void)willStartLiveScroll:(NSNotification *)notification
{
    _inLiveScroll = YES;
    // Fetch fresh header locations for the upcoming scroll gesture. This is
    // now asynchronous (WKWebView has no synchronous JS bridge), so the very
    // first couple of scroll-sync updates in a fast flick may briefly use
    // slightly stale positions from the previous render -- acceptable, but
    // worth an eyeball check against the pre-migration feel.
    [self updateHeaderLocationsWithCompletion:nil];
}

-(void)didEndLiveScroll:(NSNotification *)notification
{
    _inLiveScroll = NO;
}

- (void)editorBoundsDidChange:(NSNotification *)notification
{
    if (!self.shouldHandleBoundsChange)
        return;

    if (!self.preferences.editorSyncScrolling)
        return;

    self.shouldHandleBoundsChange = NO;
    if (_inLiveScroll)
    {
        // Header locations were already fetched in -willStartLiveScroll:;
        // this is pure native geometry math, still fully synchronous.
        [self syncScrollers];
        self.shouldHandleBoundsChange = YES;
    }
    else
    {
        __weak typeof(self) weakSelf = self;
        [self updateHeaderLocationsWithCompletion:^{
            [weakSelf syncScrollers];
            weakSelf.shouldHandleBoundsChange = YES;
        }];
    }
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

// Preview scroll position is now tracked via the "previewScroll" script
// message (see -userContentController:didReceiveScriptMessage:).


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
        [self redrawDivider];
    }
}


#pragma mark - IBAction

- (IBAction)copyHtml:(id)sender
{
    // Dis-select things in the preview so that it's more obvious we're NOT
    // respecting the selection range (WKWebView has no selection-manipulation
    // API, so this goes through JavaScript instead).
    [self.preview evaluateJavaScript:@"window.getSelection().removeAllRanges();"
                    completionHandler:nil];

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
    panel.allowedContentTypes = @[UTTypeHTML];
    if (self.presumedFileName)
        panel.nameFieldStringValue = self.presumedFileName;

    MPExportPanelAccessoryViewController *controller =
        [[MPExportPanelAccessoryViewController alloc] init];
    controller.stylesIncluded = (BOOL)self.preferences.htmlStyleName;
    controller.highlightingIncluded = self.preferences.htmlSyntaxHighlighting;
    panel.accessoryView = controller.view;

    NSWindow *w = self.windowForSheet;
    [panel beginSheetModalForWindow:w completionHandler:^(NSInteger result) {
        if (result != NSModalResponseOK)
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
    panel.allowedContentTypes = @[UTTypePDF];
    if (self.presumedFileName)
        panel.nameFieldStringValue = self.presumedFileName;
    
    NSWindow *w = nil;
    NSArray *windowControllers = self.windowControllers;
    if (windowControllers.count > 0)
        w = [windowControllers[0] window];

    [panel beginSheetModalForWindow:w completionHandler:^(NSInteger result) {
        if (result != NSModalResponseOK)
            return;

        NSDictionary *settings = @{
            NSPrintJobDisposition: NSPrintSaveJob,
            NSPrintJobSavingURL: panel.URL,
        };
        [self printDocumentWithSettings:settings showPrintPanel:NO delegate:nil
                       didPrintSelector:NULL contextInfo:NULL];
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
    BOOL inserted = [self.editor toggleForMarkupPrefix:@"[" suffix:@"]()"];
    if (!inserted)
        return;

    NSRange selectedRange = self.editor.selectedRange;
    NSUInteger location = selectedRange.location + selectedRange.length + 2;
    selectedRange = NSMakeRange(location, 0);

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSString *url = [pb URLForType:NSPasteboardTypeString].absoluteString;
    if (url)
    {
        [self.editor insertText:url replacementRange:selectedRange];
        selectedRange.length = url.length;
    }
    self.editor.selectedRange = selectedRange;
}

- (IBAction)toggleImage:(id)sender
{
    BOOL inserted = [self.editor toggleForMarkupPrefix:@"![" suffix:@"]()"];
    if (!inserted)
        return;

    NSRange selectedRange = self.editor.selectedRange;
    NSUInteger location = selectedRange.location + selectedRange.length + 2;
    selectedRange = NSMakeRange(location, 0);

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSString *url = [pb URLForType:NSPasteboardTypeString].absoluteString;
    if (url)
    {
        [self.editor insertText:url replacementRange:selectedRange];
        selectedRange.length = url.length;
    }
    self.editor.selectedRange = selectedRange;
}

- (IBAction)toggleOrderedList:(id)sender
{
    [self.editor toggleBlockWithPattern:@"^[0-9]+ \\S" prefix:@"1. "];
}

- (IBAction)toggleUnorderedList:(id)sender
{
    NSString *marker = self.preferences.editorUnorderedListMarker;
    [self.editor toggleBlockWithPattern:@"^[\\*\\+-] \\S" prefix:marker];
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

    // If we are on an empty line, treat as normal return key; otherwise insert
    // two newlines.
    if (location == newlineBefore + 1 && location == newlineAfter)
        [self.editor insertNewline:self];
    else
        // NSMakeRange(NSNotFound, 0) is Apple's documented sentinel for
        // -insertText:replacementRange: meaning "use the current selection,
        // or the marked (IME composition) range if there is one" -- the
        // same behavior the deprecated 1-arg -insertText: had.
        [self.editor insertText:@"\n\n"
               replacementRange:NSMakeRange(NSNotFound, 0)];
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

- (IBAction)toggleToolbar:(id)sender
{
    [self.windowForSheet toggleToolbarShown:sender];
}

- (IBAction)togglePreviewPane:(id)sender
{
    [self toggleSplitterCollapsingEditorPane:NO];
}

- (IBAction)toggleEditorPane:(id)sender
{
    [self toggleSplitterCollapsingEditorPane:YES];
}

- (IBAction)render:(id)sender
{
    [self.renderer parseAndRenderLater];
}


#pragma mark - Private

- (void)toggleSplitterCollapsingEditorPane:(BOOL)forEditorPane
{
    BOOL isVisible = forEditorPane ? self.editorVisible : self.previewVisible;
    BOOL editorOnRight = self.preferences.editorOnRight;

    float targetRatio = ((forEditorPane == editorOnRight) ? 1.0 : 0.0);

    if (isVisible)
    {
        CGFloat oldRatio = self.splitView.dividerLocation;
        if (oldRatio != 0.0 && oldRatio != 1.0)
        {
            // We don't want to save these values, since they are meaningless.
            // The user should be able to switch between 100% editor and 100%
            // preview without losing the old ratio.
            self.previousSplitRatio = oldRatio;
        }
        [self setSplitViewDividerLocation:targetRatio];
    }
    else
    {
        // We have an inconsistency here, let's just go back to 0.5,
        // otherwise nothing will happen
        if (self.previousSplitRatio < 0.0)
            self.previousSplitRatio = 0.5;

        [self setSplitViewDividerLocation:self.previousSplitRatio];
    }
}

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
        [self adjustEditorInsets];
    }

    if (!changedKey || [changedKey isEqualToString:@"editorBaseFontInfo"]
            || [changedKey isEqualToString:@"editorStyleName"]
            || [changedKey isEqualToString:@"editorLineSpacing"])
    {
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineSpacing = self.preferences.editorLineSpacing;
        self.editor.defaultParagraphStyle = [style copy];
        NSFont *font = [self.preferences.editorBaseFont copy];
        if (font)
            self.editor.font = font;
        self.editor.textColor = nil;
        self.editor.backgroundColor = [NSColor clearColor];
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

        CALayer *layer = [CALayer layer];
        CGColorRef backgroundCGColor = self.editor.backgroundColor.CGColor;
        if (backgroundCGColor)
            layer.backgroundColor = backgroundCGColor;
        self.editorContainer.layer = layer;
    }
    
    if ([changedKey isEqualToString:@"editorBaseFontInfo"])
    {
        [self scaleWebview];
    }

    if (!changedKey || [changedKey isEqualToString:@"editorShowWordCount"])
    {
        if (self.preferences.editorShowWordCount)
        {
            self.wordCountWidget.hidden = NO;
            self.editorPaddingBottom.constant = 35.0;
            [self updateWordCount];
        }
        else
        {
            self.wordCountWidget.hidden = YES;
            self.editorPaddingBottom.constant = 0.0;
        }
    }

    if (!changedKey || [changedKey isEqualToString:@"editorScrollsPastEnd"])
    {
        self.editor.scrollsPastEnd = self.preferences.editorScrollsPastEnd;
        NSRect contentRect = self.editor.contentRect;
        NSSize minSize = self.editor.enclosingScrollView.contentSize;
        if (contentRect.size.height < minSize.height)
            contentRect.size.height = minSize.height;
        if (contentRect.size.width < minSize.width)
            contentRect.size.width = minSize.width;
        self.editor.frame = contentRect;
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

- (void)adjustEditorInsets
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

- (void)redrawDivider
{
    if (!self.editorVisible)
    {
        // Preview background color is fetched asynchronously (see
        // -updatePreviewBackgroundColorCache) and cached, since WKWebView
        // has no synchronous DOM access. Until the first fetch completes
        // this falls back to nil (transparent divider).
        self.splitView.dividerColor = self.cachedPreviewBackgroundColor;
    }
    else if (!self.previewVisible)
    {
        // If the editor is visible, match its background color.
        self.splitView.dividerColor = self.editor.backgroundColor;
    }
    else
    {
        // If both sides are visible, draw a default "transparent" divider.
        // This works around the possibile problem of divider's color being too
        // similar to both the editor and preview and being obscured.
        self.splitView.dividerColor = nil;
    }
}

// Fetches the preview's rendered body background color asynchronously and
// caches it for -redrawDivider to read synchronously. Called after every
// successful preview load (see -previewDidFinishLoadingContent).
- (void)updatePreviewBackgroundColorCache
{
    NSString *js = @"getComputedStyle(document.body).backgroundColor";
    __weak typeof(self) weakSelf = self;
    [self.preview evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        if (![result isKindOfClass:[NSString class]])
            return;
        NSColor *color = [NSColor colorWithHTMLName:(NSString *)result];
        if (!color)
            return;
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf)
            return;
        strongSelf.cachedPreviewBackgroundColor = color;
        if (!strongSelf.editorVisible)
            [strongSelf redrawDivider];
    }];
}

- (void)scaleWebview
{
    if (!self.preferences.previewZoomRelativeToBaseFontSize)
        return;

    CGFloat fontSize = self.preferences.editorBaseFontSize;
    if (fontSize <= 0.0)
        return;

    static const CGFloat defaultSize = 14.0;
    CGFloat scale = fontSize / defaultSize;

    // WKWebView exposes zoom as a public property (macOS 11+), unlike the
    // legacy WebView which required the private -setPageSizeMultiplier:.
    self.preview.pageZoom = scale;
}

- (void)updateHeaderLocationsWithCompletion:(void (^)(void))completion
{
    // Cache the locations of all of the reference nodes in the editor view.
    // This part is pure native geometry and stays fully synchronous.
    NSMutableArray<NSNumber *> *locations = [NSMutableArray array];
    NSInteger characterCount = 0;
    NSLayoutManager *layoutManager = [self.editor layoutManager];
    NSArray<NSString *> *documentLines = [self.editor.string componentsSeparatedByString:@"\n"];
    [locations removeAllObjects];

    // These are the patterns for markdown headers and images respectively. we're only going to
    // handle images that are not inline with other text/images
    NSRegularExpression *dashRegex = [NSRegularExpression regularExpressionWithPattern:@"^([-]+)$" options:0 error:nil];
    NSRegularExpression *headerRegex = [NSRegularExpression regularExpressionWithPattern:@"^(#+)\\s" options:0 error:nil];
    NSRegularExpression *imgRegex = [NSRegularExpression regularExpressionWithPattern:@"^!\\[[^\\]]*\\]\\([^)]*\\)$" options:0 error:nil];
    BOOL previousLineHadContent = NO;
    
    CGFloat editorContentHeight = ceilf(NSHeight(self.editor.enclosingScrollView.documentView.bounds));
    CGFloat editorVisibleHeight = ceilf(NSHeight(self.editor.enclosingScrollView.contentView.bounds));

    // We start by splitting our document into lines, and then searching
    // line by line for headers or images.
    for (NSInteger lineNumber = 0; lineNumber < [documentLines count]; lineNumber++)
    {
        NSString *line = documentLines[lineNumber];
        
        if ((previousLineHadContent && [dashRegex numberOfMatchesInString:line options:0 range:NSMakeRange(0, [line length])]) ||
            [imgRegex numberOfMatchesInString:line options:0 range:NSMakeRange(0, [line length])] ||
            [headerRegex numberOfMatchesInString:line options:0 range:NSMakeRange(0, [line length])])
        {
            // Calculate where this header/image appears vertically in the editor
            NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:NSMakeRange(characterCount, [line length]) actualCharacterRange:nil];
            NSRect topRect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:[self.editor textContainer]];
            CGFloat headerY = NSMidY(topRect);

            if(headerY <= editorContentHeight - editorVisibleHeight){
                [locations addObject:@(headerY)];
            }
        }
        
        previousLineHadContent = [line length] && ![dashRegex numberOfMatchesInString:line options:0 range:NSMakeRange(0, [line length])];
        
        characterCount += [line length] + 1;
    }

    _editorHeaderLocations = [locations copy];

    // Next, fetch the vertical positions of the same reference nodes (already
    // adjusted for the preview's current scroll offset), plus the full
    // scrollable document height, from the rendered preview. This requires a
    // round trip into WKWebView's JS context, so it's asynchronous -- unlike
    // the editor-side geometry above, which stays fully native and synchronous.
    NSString *js =
        @"(function () {"
        @"    var offset = window.scrollY;"
        @"    var nodes = Array.prototype.slice.call(document.querySelectorAll("
        @"        'h1, h2, h3, h4, h5, h6, img:only-child'));"
        @"    var headers = nodes.map(function (n) {"
        @"        return n.getBoundingClientRect().top + offset;"
        @"    });"
        @"    return { headers: headers, scrollHeight: document.documentElement.scrollHeight };"
        @"})();";
    __weak typeof(self) weakSelf = self;
    [self.preview evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf)
            return;
        if ([result isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *dict = (NSDictionary *)result;
            if ([dict[@"headers"] isKindOfClass:[NSArray class]])
                strongSelf->_webViewHeaderLocations = dict[@"headers"];
            if ([dict[@"scrollHeight"] isKindOfClass:[NSNumber class]])
                strongSelf.cachedPreviewContentHeight =
                    [dict[@"scrollHeight"] doubleValue];
        }
        if (completion)
            completion();
    }];
}

- (void)syncScrollers
{
    CGFloat editorContentHeight = ceilf(NSHeight(self.editor.enclosingScrollView.documentView.bounds));
    CGFloat editorVisibleHeight = ceilf(NSHeight(self.editor.enclosingScrollView.contentView.bounds));
    CGFloat previewContentHeight = ceilf(self.cachedPreviewContentHeight);
    CGFloat previewVisibleHeight = ceilf(NSHeight(self.preview.bounds));
    NSInteger relativeHeaderIndex = -1; // -1 is start of document, before any other header
    CGFloat currY = NSMinY(self.editor.enclosingScrollView.contentView.bounds);
    CGFloat minY = 0;
    CGFloat maxY = 0;
    
    // align the documents at the middle of the screen, except at top/bottom of document
    CGFloat topTaper = MAX(0, MIN(1.0, currY / editorVisibleHeight));
    CGFloat bottomTaper = 1.0 - MAX(0, MIN(1.0, (currY - editorContentHeight + 2 * editorVisibleHeight) / editorVisibleHeight));
    CGFloat adjustmentForScroll = topTaper * bottomTaper * editorVisibleHeight / 2;

    // We start by splitting our document into lines, and then searching
    // line by line for headers or images.
    for (NSNumber *headerYNum in _editorHeaderLocations) {
        CGFloat headerY = [headerYNum floatValue];
        headerY -= adjustmentForScroll;
        
        if (headerY < currY)
        {
            // The header is before our current scroll position. the closest
            // of these will be our first reference node
            relativeHeaderIndex += 1;
            minY = headerY;
        } else if (maxY == 0 && headerY < editorContentHeight - editorVisibleHeight)
        {
            // Skip any headers that are within the last screen of the editor.
            // we'll interpolate to the end of the document in that case.
            maxY = headerY;
        }
    }
    
    // Usually, we'll be scrolling between two reference nodes, but toward the end
    // of the document we'll ignore nodes and reference the end of the document instead
    BOOL interpolateToEndOfDocument = NO;
    
    if (maxY == 0)
    {
        // We only have a reference node before our current position,
        // but not after, so we'll use the end of the document.
        maxY = editorContentHeight - editorVisibleHeight + adjustmentForScroll;
        interpolateToEndOfDocument = YES;
    }

    // We are currently at currY offset, between minY and maxY, which represent
    // headers indexed by relativeHeaderIndex and relativeHeaderIndex+1.
    currY = MAX(0, currY - minY);
    maxY -= minY;
    minY -= minY;
    CGFloat percentScrolledBetweenHeaders = MAX(0, MIN(1.0, currY / maxY));
    
    // Now that we know where the editor position is relative to two reference nodes,
    // we need to find the positions of those nodes in the HTML preview
    CGFloat topHeaderY = 0;
    CGFloat bottomHeaderY = previewContentHeight - previewVisibleHeight;
    
    // Find the Y positions in the preview window that we're scrolling between
    if ([_webViewHeaderLocations count] > relativeHeaderIndex)
    {
        topHeaderY = floorf([_webViewHeaderLocations[relativeHeaderIndex] doubleValue]) - adjustmentForScroll;
    }
    
    if (!interpolateToEndOfDocument && [_webViewHeaderLocations count] > relativeHeaderIndex + 1)
    {
        bottomHeaderY = ceilf([_webViewHeaderLocations[relativeHeaderIndex + 1] doubleValue]) - adjustmentForScroll;
    }
    
    // Now we scroll percentScrolledBetweenHeaders percent between those two positions in the webview
    CGFloat previewY = topHeaderY + (bottomHeaderY - topHeaderY) * percentScrolledBetweenHeaders;
    // WKWebView exposes no NSScrollView on macOS, so the scroll offset is set
    // via JavaScript instead of directly manipulating an NSClipView's bounds.
    NSString *js = [NSString stringWithFormat:@"window.scrollTo(0, %f);", previewY];
    [self.preview evaluateJavaScript:js completionHandler:nil];
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
        return NSLocalizedString(@"Untitled", @"default filename if no title can be determined");

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

// Mirrors the counting rules of the old DOMNode+Text.h native DOM walk:
// text inside <script>/<style>/<head> is excluded entirely; an inline
// <code> counts as exactly one "word" if non-empty; a fenced code block
// (<pre><code>) is excluded from all three counts.
static NSString * const kMPWordCountScript =
    @"(function () {"
    @"    function numberOfWords(text) {"
    @"        var m = text.match(/[^\\s]+/g);"
    @"        return m ? m.length : 0;"
    @"    }"
    @"    function lengthWithoutNewlines(text) {"
    @"        return text.replace(/[\\r\\n]/g, '').length;"
    @"    }"
    @"    function lengthWithoutWhitespace(text) {"
    @"        return text.replace(/\\s/g, '').length;"
    @"    }"
    @"    function walk(node, counts) {"
    @"        var nodeType = node.nodeType;"
    @"        if (nodeType === 1 || nodeType === 9 || nodeType === 11) {"
    @"            var tag = node.tagName ? node.tagName.toUpperCase() : '';"
    @"            if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'HEAD') return;"
    @"            if (tag === 'CODE') {"
    @"                var isBlock = node.parentElement"
    @"                    && node.parentElement.tagName === 'PRE';"
    @"                if (isBlock) return;"
    @"                var childCounts = { words: 0, characters: 0, charactersWithoutSpaces: 0 };"
    @"                for (var c = node.firstChild; c; c = c.nextSibling)"
    @"                    walk(c, childCounts);"
    @"                counts.characters += childCounts.characters;"
    @"                counts.charactersWithoutSpaces += childCounts.charactersWithoutSpaces;"
    @"                counts.words += childCounts.words > 0 ? 1 : 0;"
    @"                return;"
    @"            }"
    @"            for (var child = node.firstChild; child; child = child.nextSibling)"
    @"                walk(child, counts);"
    @"        } else if (nodeType === 3 || nodeType === 4) {"
    @"            var text = node.nodeValue || '';"
    @"            counts.words += numberOfWords(text);"
    @"            counts.characters += lengthWithoutNewlines(text);"
    @"            counts.charactersWithoutSpaces += lengthWithoutWhitespace(text);"
    @"        }"
    @"    }"
    @"    var counts = { words: 0, characters: 0, charactersWithoutSpaces: 0 };"
    @"    walk(document, counts);"
    @"    return counts;"
    @"})();";

- (void)updateWordCount
{
    __weak typeof(self) weakSelf = self;
    [self.preview evaluateJavaScript:kMPWordCountScript
                    completionHandler:^(id result, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || ![result isKindOfClass:[NSDictionary class]])
            return;
        NSDictionary *count = (NSDictionary *)result;
        strongSelf.totalWords = [count[@"words"] unsignedIntegerValue];
        strongSelf.totalCharacters = [count[@"characters"] unsignedIntegerValue];
        strongSelf.totalCharactersNoSpaces =
            [count[@"charactersWithoutSpaces"] unsignedIntegerValue];

        if (strongSelf.isPreviewReady)
            strongSelf.wordCountWidget.enabled = YES;
    }];
}

- (BOOL)isCurrentBaseUrl:(NSURL *)another
{
    NSString *mine = self.currentBaseUrl.absoluteBaseURLString;
    NSString *theirs = another.absoluteBaseURLString;
    return mine == theirs || [mine isEqualToString:theirs];
}


#define OPEN_FAIL_ALERT_INFORMATIVE NSLocalizedString( \
@"Please check the path of your link is correct. Turn on \
“Automatically create link targets” If you want MacDown to \
create nonexistent link targets for you.", \
@"preview navigation error information")

#define AUTO_CREATE_FAIL_ALERT_INFORMATIVE NSLocalizedString( \
@"MacDown can’t create a file for the clicked link because \
the current file is not saved anywhere yet. Save the \
current file somewhere to enable this feature.", \
@"preview navigation error information")

#define BLOCKED_EXECUTABLE_ALERT_INFORMATIVE NSLocalizedString( \
@"For your safety, MacDown does not open applications or other \
executables linked from a previewed document. If you trust this file, \
open it yourself from Finder.", \
@"preview navigation error information")


// CVE-2019-12138 / CVE-2019-12173: MacDown used to hand any resolved local
// link target straight to -[NSWorkspace openURL:], including .app bundles
// and other executables reached via an absolute file:// path or "../"
// traversal in the previewed (possibly untrusted) Markdown source --
// letting a malicious document silently launch an arbitrary local
// application when the user clicked a disguised link. This checks the
// *resolved* file's actual type rather than pattern-matching the URL
// string, so it isn't foolable by encoding/traversal tricks the way a
// substring blocklist would be.
- (BOOL)urlIsBlockedExecutable:(NSURL *)url
{
    if (!url.isFileURL)
        return NO;

    NSString *typeIdentifier = nil;
    if (![url getResourceValue:&typeIdentifier forKey:NSURLTypeIdentifierKey
                          error:NULL]
            || !typeIdentifier)
        return NO;

    UTType *type = [UTType typeWithIdentifier:typeIdentifier];
    if (!type)
        return NO;

    return ([type conformsToType:UTTypeApplication]
             || [type conformsToType:UTTypeExecutable]);
}

// CVE-2019-12138: also restrict where a *new* file can be auto-created for
// a nonexistent link target, so a "../../../etc/whatever"-style target in
// a previewed document can't write outside the document's own folder.
- (BOOL)url:(NSURL *)url isWithinDirectory:(NSURL *)directory
{
    NSString *targetPath = url.standardizedURL.path;
    NSString *dirPath = directory.standardizedURL.path;
    if (!targetPath || !dirPath)
        return NO;
    if (![dirPath hasSuffix:@"/"])
        dirPath = [dirPath stringByAppendingString:@"/"];
    return [targetPath hasPrefix:dirPath];
}

- (void)openOrCreateFileForUrl:(NSURL *)url
{
    // Simply open the file if it is not local, or exists already.
    BOOL file = url.isFileURL;
    BOOL reachable = !file || [url checkResourceIsReachableAndReturnError:NULL];

    // If the file is local but doesn't exist, check if a file with
    // the .md extension exists.
    if (file && !reachable && [url.pathExtension isEqualToString:@""])
    {
        NSURL *markdownURL = [url URLByAppendingPathExtension:@"md"];
        if ([markdownURL checkResourceIsReachableAndReturnError:NULL])
        {
            reachable = YES;
            url = markdownURL;
        }
    }

    if (reachable)
    {
        if ([self urlIsBlockedExecutable:url])
        {
            NSAlert *alert = [[NSAlert alloc] init];
            NSString *template = NSLocalizedString(
                @"Won’t open executable:\n%@",
                @"preview navigation error message");
            alert.messageText = [NSString stringWithFormat:template,
                                 url.path];
            alert.informativeText = BLOCKED_EXECUTABLE_ALERT_INFORMATIVE;
            [alert runModal];
            return;
        }
        [[NSWorkspace sharedWorkspace] openURL:url];
        return;
    }

    // Show an error if the user doesn't want us to create it automatically.
    if (!self.preferences.createFileForLinkTarget)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        NSString *template = NSLocalizedString(
            @"File not found at path:\n%@",
            @"preview navigation error message");
        alert.messageText = [NSString stringWithFormat:template, url.path];
        alert.informativeText = OPEN_FAIL_ALERT_INFORMATIVE;
        [alert runModal];
        return;
    }

    // We can only create a file if the current file is saved. (Why?)
    if (!self.fileURL)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        NSString *template = NSLocalizedString(
            @"Can’t create file:\n%@", @"preview navigation error message");
        alert.messageText = [NSString stringWithFormat:template,
                             url.lastPathComponent];
        alert.informativeText = AUTO_CREATE_FAIL_ALERT_INFORMATIVE;
        [alert runModal];
        return;
    }

    // Confine auto-created link targets to the document's own folder, so a
    // "../"-laden link in a previewed document can't create files outside
    // it (the other half of CVE-2019-12138).
    NSURL *documentDirectory = self.fileURL.URLByDeletingLastPathComponent;
    if (![self url:url isWithinDirectory:documentDirectory])
    {
        NSAlert *alert = [[NSAlert alloc] init];
        NSString *template = NSLocalizedString(
            @"Can’t create file:\n%@", @"preview navigation error message");
        alert.messageText = [NSString stringWithFormat:template,
                             url.lastPathComponent];
        alert.informativeText = NSLocalizedString(
            @"The link target is outside the current document’s folder, "
            @"so MacDown won’t create it automatically.",
            @"preview navigation error information");
        [alert runModal];
        return;
    }

    // Try to created the file.
    NSDocumentController *controller =
        [NSDocumentController sharedDocumentController];

    NSError *error = nil;
    id doc = [controller createNewEmptyDocumentForURL:url
                                              display:YES error:&error];
    if (!doc)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        NSString *template = NSLocalizedString(
            @"Can’t create file:\n%@",
            @"preview navigation error message");
        alert.messageText =
            [NSString stringWithFormat:template, url.lastPathComponent];
        template = NSLocalizedString(
            @"An error occurred while creating the file:\n%@",
            @"preview navigation error information");
        alert.informativeText =
            [NSString stringWithFormat:template, error.localizedDescription];
        [alert runModal];
    }
}


- (void)document:(NSDocument *)doc didPrint:(BOOL)ok context:(void *)context
{
    if ([doc respondsToSelector:@selector(setPrinting:)])
        ((MPDocument *)doc).printing = NO;
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
