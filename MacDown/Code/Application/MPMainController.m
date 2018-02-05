//
//  MPMainController.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPMainController.h"
#import <MASPreferences/MASPreferencesWindowController.h>
#import <Sparkle/SUUpdater.h>
#import "MPGlobals.h"
#import "MPUtilities.h"
#import "NSDocumentController+Document.h"
#import "NSUserDefaults+Suite.h"
#import "MPPreferences.h"
#import "MPGeneralPreferencesViewController.h"
#import "MPMarkdownPreferencesViewController.h"
#import "MPEditorPreferencesViewController.h"
#import "MPHtmlPreferencesViewController.h"
#import "NSTouchBarItem+QuickConstructor.h"
#import "MPPlugInController.h"
#import "MPTerminalPreferencesViewController.h"
#import "MPDocument.h"


static NSString * const kMPTreatLastSeenStampKey = @"treatLastSeenStamp";


NS_INLINE void MPOpenBundledFile(NSString *resource, NSString *extension)
{
    NSURL *source = [[NSBundle mainBundle] URLForResource:resource
                                            withExtension:extension];
    NSString *filename = source.absoluteString.lastPathComponent;
    NSURL *target = [NSURL fileURLWithPathComponents:@[NSTemporaryDirectory(),
                                                       filename]];
    BOOL ok = NO;
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager removeItemAtURL:target error:NULL];
    ok = [manager copyItemAtURL:source toURL:target error:NULL];

    if (!ok)
        return;
    NSDocumentController *c = [NSDocumentController sharedDocumentController];
    [c openDocumentWithContentsOfURL:target display:YES completionHandler:
     ^(NSDocument *document, BOOL wasOpen, NSError *error) {
         if (!document || wasOpen || error)
             return;
         NSRect frame = [NSScreen mainScreen].visibleFrame;
         for (NSWindowController *wc in document.windowControllers)
             [wc.window setFrame:frame display:YES];
     }];
}

NS_INLINE void treat()
{
    NSDictionary *info = MPGetDataMap(@"treats");
    NSString *name = info[@"name"];
    if (![NSUserName().lowercaseString hasPrefix:name]
            && ![NSFullUserName().lowercaseString hasPrefix:name])
        return;

    NSDictionary *data = info[@"data"];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSCalendarUnit unit =
        NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear;
    NSDateComponents *comps = [calendar components:unit fromDate:[NSDate date]];

    NSString *key =
        [NSString stringWithFormat:@"%02ld%02ld", comps.month, comps.day];
    if (!data[key])     // No matching treat.
        return;

    NSString *stamp = [NSString stringWithFormat:@"%ld%02ld%02ld",
                       comps.year, comps.month, comps.day];

    // User has seen this treat today.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([[defaults objectForKey:kMPTreatLastSeenStampKey] isEqual:stamp])
        return;

    [defaults setObject:stamp forKey:kMPTreatLastSeenStampKey];
    NSArray *components = @[NSTemporaryDirectory(), key];
    NSURL *url = [NSURL fileURLWithPathComponents:components];
    [data[key] writeToURL:url atomically:NO];

    // Make sure this is opened last and immediately visible.
    NSDocumentController *c = [NSDocumentController sharedDocumentController];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [c openDocumentWithContentsOfURL:url display:YES
                       completionHandler:MPDocumentOpenCompletionEmpty];
    }];
}


@interface MPMainController ()

@property (weak) IBOutlet MPPlugInController *pluginController;

@property (readonly) NSWindowController *preferencesWindowController;
@property (strong) NSDictionary<NSString *, NSTouchBarItem *>
	*pluginTouchBarItems;

@end


@implementation MPMainController

@synthesize preferencesWindowController = _preferencesWindowController;

- (MPPreferences *)preferences
{
    return [MPPreferences sharedInstance];
}

- (NSWindowController *)preferencesWindowController
{
    if (!_preferencesWindowController)
    {
        NSArray *vcs = @[
            [[MPGeneralPreferencesViewController alloc] init],
            [[MPMarkdownPreferencesViewController alloc] init],
            [[MPEditorPreferencesViewController alloc] init],
            [[MPHtmlPreferencesViewController alloc] init],
            [[MPTerminalPreferencesViewController alloc] init],
        ];
        NSString *title = NSLocalizedString(@"Preferences",
                                            @"Preferences window title.");

        typedef MASPreferencesWindowController WC;
        _preferencesWindowController =
            [[WC alloc] initWithViewControllers:vcs title:title];
    }
    return _preferencesWindowController;
}

- (IBAction)showPreferencesWindow:(id)sender
{
    [self.preferencesWindowController showWindow:nil];
}

- (IBAction)showHelp:(id)sender
{
    MPOpenBundledFile(@"help", @"md");
}

- (NSArray<NSTouchBarItemIdentifier> *)pluginEditorTouchBarItems
{
    return [[self pluginTouchBarItems] allKeys];
}


#pragma mark - Override

- (instancetype)init
{
    self = [super init];
    if (!self)
        return self;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(showFirstLaunchTips)
                   name:MPDidDetectFreshInstallationNotification
                 object:self.preferences];
    [self copyFiles];
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    [self setPluginTouchBarItems:[[self pluginController] makeTouchBarItems]];
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSApplication *application = [NSApplication sharedApplication];

    // Enables automatic installation of the "Customize Touch Bar…" menu item,
    // by Apple's recomendation
    if ([application respondsToSelector:
         @selector(setAutomaticCustomizeTouchBarMenuItemEnabled:)])
    {
        [application setAutomaticCustomizeTouchBarMenuItemEnabled:YES];
    }

    // Using private API [WebCache setDisabled:YES] to disable WebView's cache
    id webCacheClass = (id)NSClassFromString(@"WebCache");
    if (webCacheClass) {
        // Ignoring "undeclared selector" warning
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        BOOL setDisabledValue = YES;
        NSMethodSignature *signature = [webCacheClass methodSignatureForSelector:@selector(setDisabled:)];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.selector = @selector(setDisabled:);
        invocation.target = [webCacheClass class];
        [invocation setArgument:&setDisabledValue atIndex:2];
        [invocation invoke];
#pragma clang diagnostic pop
    }
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    if (self.preferences.filesToOpen.count || self.preferences.pipedContentFileToOpen)
        return NO;
    return !self.preferences.supressesUntitledDocumentOnLaunch;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self openPendingPipedContent];
    [self openPendingFiles];
    treat();
}


#pragma mark - SUUpdaterDelegate

- (NSString *)feedURLStringForUpdater:(SUUpdater *)updater
{
    if (self.preferences.updateIncludesPreReleases)
        return [NSBundle mainBundle].infoDictionary[@"SUBetaFeedURL"];
    return [NSBundle mainBundle].infoDictionary[@"SUFeedURL"];
}


#pragma mark - Private

- (void)copyFiles
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *root = MPDataDirectory(nil);
    if (![manager fileExistsAtPath:root])
    {
        [manager createDirectoryAtPath:root
           withIntermediateDirectories:YES attributes:nil error:NULL];
    }

    NSBundle *bundle = [NSBundle mainBundle];
    for (NSString *key in @[kMPStylesDirectoryName, kMPThemesDirectoryName])
    {
        NSURL *dirSource = [bundle URLForResource:key withExtension:@""];
        NSURL *dirTarget = [NSURL fileURLWithPath:MPDataDirectory(key)];

        // If the directory doesn't exist, just copy the whole thing.
        if (![manager fileExistsAtPath:dirTarget.path])
        {
            [manager copyItemAtURL:dirSource toURL:dirTarget error:NULL];
            continue;
        }

        // Check for existence of each file and copy if it's not there.
        NSArray *contents = [manager contentsOfDirectoryAtURL:dirSource
                                   includingPropertiesForKeys:nil options:0
                                                        error:NULL];
        for (NSURL *fileSource in contents)
        {
            NSString *name = fileSource.lastPathComponent;
            NSURL *fileTarget = [dirTarget URLByAppendingPathComponent:name];
            if (![manager fileExistsAtPath:fileTarget.path])
                [manager copyItemAtURL:fileSource toURL:fileTarget error:NULL];
        }
    }
}

- (void)openPendingFiles
{
    NSDocumentController *c = [NSDocumentController sharedDocumentController];

    for (NSString *path in self.preferences.filesToOpen)
    {
        NSURL *url = [NSURL fileURLWithPath:path];
        if ([url checkResourceIsReachableAndReturnError:NULL])
        {
            [c openDocumentWithContentsOfURL:url display:YES
                           completionHandler:MPDocumentOpenCompletionEmpty];
        }
        else
        {
            [c createNewEmptyDocumentForURL:url display:YES error:NULL];
        }
    }

    self.preferences.filesToOpen = nil;
    [self.preferences synchronize];
}

- (void)openPendingPipedContent {
    NSDocumentController *c = [NSDocumentController sharedDocumentController];
    
    if (self.preferences.pipedContentFileToOpen) {
        NSURL *pipedContentFileToOpenURL = [NSURL fileURLWithPath:self.preferences.pipedContentFileToOpen];
        NSError *readPipedContentError;
        NSString *pipedContentString = [NSString stringWithContentsOfURL:pipedContentFileToOpenURL encoding:NSUTF8StringEncoding error:&readPipedContentError];
        
        NSError *openDocumentError;
        MPDocument *document = (MPDocument *)[c openUntitledDocumentAndDisplay:YES error:&openDocumentError];
        
        if (document && openDocumentError == nil && readPipedContentError == nil) {
            document.markdown = pipedContentString;
        }
        
        self.preferences.pipedContentFileToOpen = nil;
        [self.preferences synchronize];
    }
}


#pragma mark - Notification handler

- (void)showFirstLaunchTips
{
    [self showHelp:nil];
}

#pragma mark - Touch Bar Delegate

- (NSTouchBarItem *)customItem:(NSTouchBarItemIdentifier)identifier
                      withView:(NSView *)view
                      andLabel:(NSString *)label
{
    NSCustomTouchBarItem *item = [NSTouchBarItem customWith:identifier];
    [view setTranslatesAutoresizingMaskIntoConstraints:YES];
    [item setView:view];
    [item setCustomizationLabel:label];
    [view setIdentifier:identifier];

    return item;
}

- (NSTouchBarItem *)buttonItem:(NSTouchBarItemIdentifier)identifier
                    imageNamed:(NSString *)imageName
                      andLabel:(NSString *)label
{
    SEL selector = @selector(sendProxyTouchBarActionToCurrentDocument:);

    NSButton *button = [NSButton buttonWithImage:[NSImage imageNamed:imageName]
                                          target:self
                                          action:selector];

    return [self customItem:identifier
                   withView:button
                   andLabel:label];
}

- (NSTouchBarItem *)buttonItem:(NSTouchBarItemIdentifier)identifier
                   buttonTitle:(NSString *)buttonTitle
                      andLabel:(NSString *)label
{
    SEL selector = @selector(sendProxyTouchBarActionToCurrentDocument:);

    NSButton *button = [NSButton buttonWithTitle:buttonTitle
                                          target:self
                                          action:selector];

    return [self customItem:identifier
                   withView:button
                   andLabel:label];
}

- (NSTouchBarItem *)segmentedItem:(NSTouchBarItemIdentifier)identifier
                           images:(NSArray<NSImage *> *)images
                         andLabel:(NSString *)label
{
    return [self segmentedItem:identifier
                        images:images
                segmentedStyle:NSSegmentStyleAutomatic
                      andLabel:label];
}

- (NSTouchBarItem *)segmentedItem:(NSTouchBarItemIdentifier)identifier
                           images:(NSArray<NSImage *> *)images
                   segmentedStyle:(NSSegmentStyle)segmentedStyle
                         andLabel:(NSString *)label
{
    SEL selector = @selector(sendProxyTouchBarActionToCurrentDocument:);
    NSSegmentedControl *control = [NSSegmentedControl
                                   segmentedControlWithImages:images
                                   trackingMode:NSSegmentSwitchTrackingMomentary
                                   target:self
                                   action:selector];

    [control setSegmentStyle:segmentedStyle];

    for (NSInteger i=0, k=[images count]; i<k; i++)
    {
        [control setWidth:52. forSegment:i];
    }

    return [self customItem:identifier withView:control andLabel:label];
}

- (NSTouchBarItem *)textFormattingGroupTouchBarItem:(NSTouchBar *)touchBar
{
    id identifier = MPTouchBarItemFormattingIdentifier;

    NSMutableArray *images = [@[
        [NSImage imageNamed:NSImageNameTouchBarTextBoldTemplate],
        [NSImage imageNamed:NSImageNameTouchBarTextItalicTemplate]
    ] mutableCopy];

    if (self.preferences.extensionUnderline)
    {
        [images addObject:
         [NSImage imageNamed:NSImageNameTouchBarTextUnderlineTemplate]];
    }

    NSString *label = NSLocalizedString(@"Text Formatting",
                                        @"TouchBar button label");

    return [self segmentedItem:identifier
                        images:images
                segmentedStyle:NSSegmentStyleSeparated
                      andLabel:label];
}

- (NSTouchBarItem *)listsGroupTouchBarItem:(NSTouchBar *)touchBar
{
    id identifier = MPTouchBarItemListsIdentifier;

    NSArray *images = @[
        [NSImage imageNamed:@"UnorderedList"],
        [NSImage imageNamed:@"OrderedList"]
    ];

    NSString *label = NSLocalizedString(@"Lists",
                                        @"TouchBar button label");

    return [self segmentedItem:identifier
                        images:images
                segmentedStyle:NSSegmentStyleSeparated
                      andLabel:label];
}

- (NSTouchBarItem *)shiftTextGroupTouchBarItem:(NSTouchBar *)touchBar
{
    id identifier = MPTouchBarItemShiftIdentifier;

    NSArray *images = @[
        [NSImage imageNamed:@"ShiftLeft"],
        [NSImage imageNamed:@"ShiftRight"]
    ];

    NSString *label = NSLocalizedString(@"Shift Text",
                                        @"TouchBar button label");

    return [self segmentedItem:identifier
                        images:images
                segmentedStyle:NSSegmentStyleSeparated
                      andLabel:label];
}

- (NSTouchBarItem *)paragraphPopoverTouchBarItem
{
    id identifier = MPTouchBarItemHeadingPopIdentifier;
    NSPopoverTouchBarItem *item = [[NSPopoverTouchBarItem alloc]
                                   initWithIdentifier:identifier];

    NSTouchBar *subTouchBar = [[NSTouchBar alloc] init];
    [subTouchBar setDelegate:self];

    [subTouchBar setDefaultItemIdentifiers:@[
        MPTouchBarItemH1Identifier,
        MPTouchBarItemH2Identifier,
        MPTouchBarItemH3Identifier,
        MPTouchBarItemH4Identifier,
        MPTouchBarItemH5Identifier,
        MPTouchBarItemH6Identifier,
        MPTouchBarItemH0Identifier
    ]];

    [item setPopoverTouchBar:subTouchBar];
    [item setPressAndHoldTouchBar:subTouchBar];
    [item setCollapsedRepresentationImage:[NSImage imageNamed:@"Headings"]];
    [item setShowsCloseButton:YES];
    [item setCustomizationLabel:NSLocalizedString(@"Paragraph Types",
                                                  @"TouchBar button label")];

    return item;
}

- (NSTouchBarItem *)layoutGroupTouchBarItem:(NSTouchBar *)touchBar
{
    id identifier = MPTouchBarItemLayoutIdentifier;
    
    NSMutableArray *images = [@[
        [NSImage imageNamed:@"HideEditor"],
        [NSImage imageNamed:@"EditorAndPreview"],
        [NSImage imageNamed:@"HidePreview"]
    ] mutableCopy];
    
    NSString *label = NSLocalizedString(@"Layout",
                                        @"TouchBar button label");
    
    return [self segmentedItem:identifier images:images andLabel:label];
}

-(NSTouchBarItem *)layoutPopoverTouchBarItem
{
    id identifier = MPTouchBarItemLayoutPopIdentifier;
    NSPopoverTouchBarItem *item = [[NSPopoverTouchBarItem alloc]
                                   initWithIdentifier:identifier];
    
    NSTouchBar *subTouchBar = [[NSTouchBar alloc] init];
    [subTouchBar setDelegate:self];
    
    [subTouchBar setDefaultItemIdentifiers:@[
        MPTouchBarItemLayoutIdentifier
    ]];
    
    [item setPopoverTouchBar:subTouchBar];
    [item setPressAndHoldTouchBar:subTouchBar];
    [item setCollapsedRepresentationImage:[NSImage imageNamed:@"EditorAndPreview"]];
    [item setShowsCloseButton:YES];
    [item setCustomizationLabel:NSLocalizedString(@"Layout",
                                                  @"TouchBar button label")];
    
    return item;
}

- (NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar
       makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
    if ([identifier isEqualToString:MPTouchBarItemFormattingIdentifier])
    {
        return [self textFormattingGroupTouchBarItem:touchBar];
    }
    else if ([identifier isEqualToString:MPTouchBarItemListsIdentifier])
    {
        return [self listsGroupTouchBarItem:touchBar];
    }
    else if ([identifier isEqualToString:MPTouchBarItemHeadingPopIdentifier])
    {
        return [self paragraphPopoverTouchBarItem];
    }
    else if ([identifier isEqualToString:MPTouchBarItemShiftIdentifier])
    {
        return [self shiftTextGroupTouchBarItem:touchBar];
    }
    else if ([identifier isEqualToString:MPTouchBarItemLinkIdentifier])
    {
        return [self buttonItem:identifier
                     imageNamed:@"Link"
                       andLabel:NSLocalizedString(@"Link",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemImageIdentifier])
    {
        return [self buttonItem:identifier
                     imageNamed:@"Image"
                       andLabel:NSLocalizedString(@"Image",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemCodeIdentifier])
    {
        return [self buttonItem:identifier
                     imageNamed:@"InlineCode"
                       andLabel:NSLocalizedString(@"Inline Code",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemCommentIdentifier])
    {
        return [self buttonItem:identifier
                     imageNamed:@"Comment"
                       andLabel:NSLocalizedString(@"Markdown Comment",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemBlockquoteIdentifier])
    {
        return [self buttonItem:identifier
                     imageNamed:@"Blockquote"
                       andLabel:NSLocalizedString(@"Blockquote",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemH1Identifier])
    {
        return [self buttonItem:identifier
                    buttonTitle:@"H1"
                       andLabel:NSLocalizedString(@"Header 1",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemH2Identifier])
    {
        return [self buttonItem:identifier
                    buttonTitle:@"H2"
                       andLabel:NSLocalizedString(@"Header 2",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemH3Identifier])
    {
        return [self buttonItem:identifier
                    buttonTitle:@"H3"
                       andLabel:NSLocalizedString(@"Header 3",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemH4Identifier])
    {
        return [self buttonItem:identifier
                    buttonTitle:@"H4"
                       andLabel:NSLocalizedString(@"Header 4",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemH5Identifier])
    {
        return [self buttonItem:identifier
                    buttonTitle:@"H5"
                       andLabel:NSLocalizedString(@"Header 5",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemH6Identifier])
    {
        return [self buttonItem:identifier
                    buttonTitle:@"H6"
                       andLabel:NSLocalizedString(@"Header 6",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemH0Identifier])
    {
        return [self buttonItem:identifier
                    buttonTitle:@"Paragraph"
                       andLabel:NSLocalizedString(@"Normal Paragraph",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemCopyHTMLIdentifier])
    {
        return [self buttonItem:identifier
                     imageNamed:@"CopyHTML"
                       andLabel:NSLocalizedString(@"Copy HTML",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemStrikeIdentifier]
             && self.preferences.extensionStrikethough)
    {
        return [self buttonItem:identifier
                     imageNamed:@"Strikethrough"
                       andLabel:NSLocalizedString(@"Strikethrough",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemHighlightIdentifier]
             && self.preferences.extensionHighlight)
    {
        return [self buttonItem:identifier
                     imageNamed:@"Highlight"
                       andLabel:NSLocalizedString(@"Highlight",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemHidePreviewIdentifier])
    {
        return [self buttonItem:identifier
                     imageNamed:@"HidePreview"
                       andLabel:NSLocalizedString(@"Hide Preview Pane",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemHideEditorIdentifier])
    {
        return [self buttonItem:identifier
                     imageNamed:@"HideEditor"
                       andLabel:NSLocalizedString(@"Hide Editor Pane",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemLayoutIdentifier])
    {
        return [self layoutGroupTouchBarItem:touchBar];
    }
    else if ([identifier isEqualToString:MPTouchBarItemLayoutPopIdentifier])
    {
        return [self layoutPopoverTouchBarItem];
    }
    else
    {
        // Try from the extra plugin items
        id item = [[self pluginTouchBarItems] objectForKey:identifier];

        if ([item isKindOfClass:[NSTouchBarItem class]])
        {
            return [[self pluginTouchBarItems] objectForKey:identifier];
        }
    }

    return nil;
}

- (NSArray<NSString *> *)extentionTouchBarIdentifiers
{
    NSMutableArray<NSString *> *enabledIdentifiers = [NSMutableArray new];

    if (self.preferences.extensionStrikethough)
    {
        [enabledIdentifiers addObject:MPTouchBarItemStrikeIdentifier];
    }

    if (self.preferences.extensionHighlight)
    {
        [enabledIdentifiers addObject:MPTouchBarItemHighlightIdentifier];
    }

    return enabledIdentifiers;
}

- (void)sendProxyTouchBarActionToCurrentDocument:(id)sender
{
    NSDocumentController *c = [NSDocumentController sharedDocumentController];
    NSDocument *currentDocument = [c currentDocument];
    NSTouchBarItemIdentifier identifier = nil;

    if ([sender isKindOfClass:[NSButton class]])
    {
        identifier = [sender identifier];
    }
    else if ([sender isKindOfClass:[NSSegmentedControl class]])
    {
        identifier = [sender identifier];

        if ([identifier isEqualToString:MPTouchBarItemFormattingIdentifier])
        {
            NSTouchBarItemIdentifier identifiers[] = {
                MPTouchBarItemStrongIdentifier,
                MPTouchBarItemEmphasisIdentifier,
                MPTouchBarItemUnderlineIdentifier
            };

            identifier = identifiers[[sender selectedSegment]];
        }
        else if ([identifier isEqualToString:MPTouchBarItemListsIdentifier])
        {
            NSTouchBarItemIdentifier identifiers[] = {
                MPTouchBarItemSimpleListIdentifier,
                MPTouchBarItemOrderedListIdentifier
            };

            identifier = identifiers[[sender selectedSegment]];
        }
        else if ([identifier isEqualToString:MPTouchBarItemShiftIdentifier])
        {
            NSTouchBarItemIdentifier identifiers[] = {
                MPTouchBarItemShiftLeftIdentifier,
                MPTouchBarItemShiftRightIdentifier
            };

            identifier = identifiers[[sender selectedSegment]];
        }
        else if ([identifier isEqualToString:MPTouchBarItemLayoutIdentifier])
        {
            NSTouchBarItemIdentifier identifiers[] = {
                MPTouchBarItemHideEditorIdentifier,
                MPTouchBarItemEqualSplitEditorIdentifier,
                MPTouchBarItemHidePreviewIdentifier
            };
            
            identifier = identifiers[[sender selectedSegment]];
        }
    }

    if ([currentDocument respondsToSelector:@selector(touchBarAction:sender:)]
        && identifier)
    {
        [currentDocument performSelector:@selector(touchBarAction:sender:)
                              withObject:identifier
                              withObject:sender];
    }
}

@end
