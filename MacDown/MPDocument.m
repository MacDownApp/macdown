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
#import "MPPreferences.h"


static const unichar kMPMatchingCharactersMap[][2] = {
    {L'(', L')'},
    {L'[', L']'},
    {L'{', L'}'},
    {L'<', L'>'},
    {L'\'', L'\''},
    {L'\"', L'\"'},
    {L'\uff08', L'\uff09'},     // full-width parentheses
    {L'\u300c', L'\u300d'},     // corner brackets
    {L'\u300e', L'\u300f'},     // white corner brackets
    {L'\u2018', L'\u2019'},     // single quotes
    {L'\u201c', L'\u201d'},     // double quotes
    {L'\0', L'\0'},
};

static const unichar kMPStrikethroughCharacter = L'~';

static const unichar kMPMarkupCharacters[] = {
    L'*', L'_', L'`', L'=', L'\0',
};


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

@implementation NSTextView (Autocompletion)

- (NSInteger)locationOfFirstNewlineBefore:(NSUInteger)location
{
    NSCharacterSet *newline = [NSCharacterSet newlineCharacterSet];
    NSString *text = self.string;
    NSInteger p = location - 1;
    while (p >= 0 && ![newline characterIsMember:[text characterAtIndex:p]])
        p--;
    return p;
}

- (NSUInteger)locationOfFirstNewlineAfter:(NSUInteger)location
{
    NSCharacterSet *newline = [NSCharacterSet newlineCharacterSet];
    NSString *text = self.string;
    NSInteger p = location + 1;
    while (p < text.length
           && ![newline characterIsMember:[text characterAtIndex:p]])
        p++;
    return p;
}

- (BOOL)substringInRange:(NSRange)range isSurroundedByPrefix:(NSString *)prefix
                  suffix:(NSString *)suffix
{
    NSString *content = self.string;
    NSUInteger location = range.location;
    NSUInteger length = range.length;
    if (content.length < location + length + suffix.length)
        return NO;
    if (location < prefix.length)
        return NO;

    if (![[content substringFromIndex:location + length] hasPrefix:suffix]
        || ![[content substringToIndex:location] hasSuffix:prefix])
        return NO;

    // Emphasis (*) requires special treatment because we need to eliminate
    // strong (**) but not strong-emphasis (***).
    if (![prefix isEqualToString:@"*"] || ![suffix isEqualToString:@"*"])
        return YES;
    if ([self substringInRange:range isSurroundedByPrefix:@"***" suffix:@"***"])
        return YES;
    if ([self substringInRange:range isSurroundedByPrefix:@"**" suffix:@"**"])
        return NO;
    return YES;
}


- (void)insertSpacesForTab
{
    NSString *spaces = @"    ";
    NSUInteger currentLocation = self.selectedRange.location;
    NSInteger p = [self locationOfFirstNewlineBefore:currentLocation];

    // Calculate how deep we need to go.
    NSUInteger offset = (currentLocation - p - 1) % 4;
    if (offset)
        spaces = [spaces substringFromIndex:offset];
    [self insertText:spaces];
}

- (BOOL)completeMatchingCharacterForText:(NSString *)string
                              atLocation:(NSUInteger)location
{
    NSString *content = self.string;

    unichar c = [string characterAtIndex:0];
    unichar n = '\0';
    if (location < content.length)
        n = [content characterAtIndex:location];

    for (const unichar *cs = kMPMatchingCharactersMap[0]; *cs != 0; cs += 2)
    {
        if (c == cs[0] && n != cs[1])
        {
            NSRange range = NSMakeRange(location, 0);
            NSString *completion = [NSString stringWithCharacters:cs length:2];
            [self insertText:completion replacementRange:range];

            range.location += string.length;
            self.selectedRange = range;
            return YES;
        }
        else if (n == cs[1])
        {
            NSRange range = NSMakeRange(location + 1, 0);
            self.selectedRange = range;
            return YES;
        }
    }
    return NO;
}

- (void)wrapTextInRange:(NSRange)range withPrefix:(unichar)prefix
                 suffix:(unichar)suffix
{
    NSString *string = [self.string substringWithRange:range];
    NSString *p = [NSString stringWithCharacters:&prefix length:1];
    NSString *s = [NSString stringWithCharacters:&suffix length:1];
    NSString *wrapped = [NSString stringWithFormat:@"%@%@%@", p, string, s];
    [self insertText:wrapped replacementRange:range];

    range.location += 1;
    self.selectedRange = range;
}

- (BOOL)wrapMatchingCharactersOfCharacter:(unichar)character
                        aroundTextInRange:(NSRange)range
                     strikethroughEnabled:(BOOL)isStrikethroughEnabled
{
    for (const unichar *cs = kMPMatchingCharactersMap[0]; *cs != 0; cs += 2)
    {
        if (character == cs[0])
        {
            [self wrapTextInRange:range withPrefix:cs[0] suffix:cs[1]];
            return YES;
        }
    }
    for (size_t i = 0; kMPMarkupCharacters[i] != 0; i++)
    {
        if (character == kMPMarkupCharacters[i])
        {
            [self wrapTextInRange:range withPrefix:character suffix:character];
            return YES;
        }
    }
    if (isStrikethroughEnabled && character == kMPStrikethroughCharacter)
    {
        [self wrapTextInRange:range withPrefix:character suffix:character];
        return YES;
    }
    return NO;
}

- (BOOL)deleteMatchingCharactersAround:(NSUInteger)location
{
    NSString *string = self.string;
    if (location == 0 || location >= string.length)
        return NO;

    unichar f = [string characterAtIndex:location - 1];
    unichar b = [string characterAtIndex:location];

    for (const unichar *cs = kMPMatchingCharactersMap[0]; *cs != 0; cs += 2)
    {
        if (f == cs[0] && b == cs[1])
        {
            [self replaceCharactersInRange:NSMakeRange(location - 1, 2)
                                withString:@""];
            return YES;
        }
    }
    return NO;
}

- (BOOL)unindentForSpacesBefore:(NSUInteger)location
{
    NSString *string = self.string;

    NSUInteger whitespaceCount = 0;
    while (location - whitespaceCount > 0
           && [string characterAtIndex:location - whitespaceCount - 1] == L' ')
    {
        whitespaceCount++;
        if (whitespaceCount >= 4)
            break;
    }
    if (whitespaceCount < 2)
        return NO;

    NSUInteger offset = ([self locationOfFirstNewlineBefore:location] + 1) % 4;
    if (offset == 0)
        offset = 4;
    offset = offset > whitespaceCount ? whitespaceCount : 4;
    NSRange range = NSMakeRange(location - offset, offset);
    [self replaceCharactersInRange:range withString:@""];
    return YES;
}

- (void)toggleForMarkupPrefix:(NSString *)prefix suffix:(NSString *)suffix
{
    NSRange range = self.selectedRange;
    NSString *selection = [self.string substringWithRange:range];

    // Selection is already marked-up. Clear markup and maintain selection.
    NSUInteger poff = prefix.length;
    if ([self substringInRange:range isSurroundedByPrefix:prefix
                        suffix:suffix])
    {
        NSRange sub = NSMakeRange(range.location - poff,
                                  selection.length + poff + suffix.length);
        [self insertText:selection replacementRange:sub];
        range.location = sub.location;
    }
    // Selection is normal. Mark it up and maintain selection.
    else
    {
        NSString *text = [NSString stringWithFormat:@"%@%@%@",
                            prefix, selection, suffix];
        [self insertText:text replacementRange:range];
        range.location += poff;
    }
    self.selectedRange = range;
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

    // Hack: Initialize preference controller before we add an observer to user
    // default changes. This prevents deadlock caused by initializing the
    // controller in a notification callback (which whould fire the callback
    // again).
    [MPPreferences sharedInstance];

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
    else if (commandSelector == @selector(deleteBackward:))
        return ![self textViewShouldDeleteBackward:textView];
    return NO;
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)range
                                              replacementString:(NSString *)str
{
    if (self.preferences.editorCompleteMatchingCharacters)
    {
        NSUInteger stringLength = str.length;

        // Character insert without selection.
        if (range.length == 0 && stringLength == 1)
        {
            NSUInteger location = range.location;
            if ([self.editor completeMatchingCharacterForText:str
                                                   atLocation:location])
                return NO;
        }
        // Character insert with selection (i.e. select and replace).
        else if (range.length > 0 && stringLength == 1)
        {
            unichar character = [str characterAtIndex:0];
            BOOL strikethrough = self.preferences.extensionStrikethough;
            if ([self.editor wrapMatchingCharactersOfCharacter:character
                                             aroundTextInRange:range
                                          strikethroughEnabled:strikethrough])
                return NO;
        }
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

- (BOOL)textViewShouldDeleteBackward:(NSTextView *)textView
{
    if (self.preferences.editorCompleteMatchingCharacters)
    {
        NSUInteger location = self.editor.selectedRange.location;
        if ([self.editor deleteMatchingCharactersAround:location])
            return NO;
    }
    if (self.preferences.editorConvertTabs)
    {
        NSUInteger location = self.editor.selectedRange.location;
        if ([self.editor unindentForSpacesBefore:location])
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
    NSUInteger start = range.location + range.length - 1;
    range.location = [self.editor locationOfFirstNewlineAfter:start];
    range.length = 0;
    self.editor.selectedRange = range;
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
