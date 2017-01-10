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
#import "MPEditorView.h"
#import "NSTouchBarItem+QuickConstructor.h"
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
@property (readonly) NSWindowController *preferencesWindowController;
@end


@implementation MPMainController

@synthesize preferencesWindowController = _preferencesWindowController;

- (MPPreferences *)prefereces
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


#pragma mark - Override

- (instancetype)init
{
    self = [super init];
    if (!self)
        return self;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(showFirstLaunchTips)
                   name:MPDidDetectFreshInstallationNotification
                 object:self.prefereces];
    [self copyFiles];
    return self;
}


#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSApplication *application = [NSApplication sharedApplication];

    // Enables automatic installation of the "Customize TouchBar…" menu item,
    // by Apple's recomendation
    if ([application respondsToSelector:
         @selector(setAutomaticCustomizeTouchBarMenuItemEnabled:)])
    {
        [application setAutomaticCustomizeTouchBarMenuItemEnabled:YES];
    }
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    if (self.prefereces.filesToOpen.count)
        return NO;
    return !self.prefereces.supressesUntitledDocumentOnLaunch;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self openPendingFiles];
}


#pragma mark - SUUpdaterDelegate

- (NSString *)feedURLStringForUpdater:(SUUpdater *)updater
{
    if (self.prefereces.updateIncludesPreReleases)
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

    for (NSString *path in self.prefereces.filesToOpen)
    {
        NSURL *url = [NSURL fileURLWithPath:path];
        if ([url checkResourceIsReachableAndReturnError:NULL])
        {
            [c openDocumentWithContentsOfURL:url display:YES
                           completionHandler:MPDocumentOpenCompletionEmpty];
        }
        else
        {
            [c openUntitledDocumentForURL:url display:YES error:NULL];
        }
    }

    self.prefereces.filesToOpen = nil;
    [self.prefereces synchronize];
    treat();
}


#pragma mark - Notification handler

- (void)showFirstLaunchTips
{
    [self showHelp:nil];
}

@end

@implementation MPMainController (TouchBarDelegate)

- (NSTouchBarItem *)customItem:(NSTouchBarItemIdentifier)identifier
                      withView:(NSView *)view
                      andLabel:(NSString *)label
{
    NSCustomTouchBarItem *item = [NSTouchBarItem customWith:identifier];
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

- (NSTouchBarItem *)textFormattingGroupTouchBarItem:(NSTouchBar *)touchBar
{
    id identifier = MPTouchBarItemFormattingIdentifier;
    SEL selector = @selector(sendProxyTouchBarActionToCurrentDocument:);

    NSArray *images = @[
        [NSImage imageNamed:NSImageNameTouchBarTextBoldTemplate],
        [NSImage imageNamed:NSImageNameTouchBarTextItalicTemplate],
        [NSImage imageNamed:NSImageNameTouchBarTextUnderlineTemplate]
    ];

    NSSegmentedControl *control = [NSSegmentedControl
                                   segmentedControlWithImages:images
                                   trackingMode:NSSegmentSwitchTrackingMomentary
                                   target:self
                                   action:selector];

    [control setWidth:48. forSegment:0];
    [control setWidth:48. forSegment:1];
    [control setWidth:48. forSegment:2];

    NSString *label = NSLocalizedString(@"Text Formatting",
                                        @"TouchBar button label");

    NSTouchBarItem *item = [self customItem:identifier
                                   withView:control
                                   andLabel:label];

    return item;
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

    NSImage *image = [NSImage imageNamed:
                      NSImageNameTouchBarTextBoxTemplate];
    NSButton *button = [NSButton buttonWithImage:image
                                          target:item
                                          action:@selector(showPopover:)];

    [item setPopoverTouchBar:subTouchBar];
    [item setPressAndHoldTouchBar:subTouchBar];
    [item setCollapsedRepresentation:button];
    [item setShowsCloseButton:YES];
    [item setCustomizationLabel:NSLocalizedString(@"Paragraph Types",
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
    else if ([identifier isEqualToString:MPTouchBarItemStrongIdentifier])
    {
        return [self buttonItem:identifier
                     imageNamed:NSImageNameTouchBarTextBoldTemplate
                       andLabel:NSLocalizedString(@"Strong",
                                                  @"TouchBar button label")];
    }
    else if ([identifier isEqualToString:MPTouchBarItemEmphasisIdentifier])
    {
         return [self buttonItem:identifier
                      imageNamed:NSImageNameTouchBarTextItalicTemplate
                        andLabel:NSLocalizedString(@"Emphasis",
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
    else if ([identifier isEqualToString:MPTouchBarItemHeadingPopIdentifier])
    {
        return [self paragraphPopoverTouchBarItem];
    }

    return nil;
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
    }

    if ([currentDocument respondsToSelector:@selector(performTouchBarAction:)]
        && identifier)
    {
        [currentDocument performSelector:@selector(performTouchBarAction:)
                              withObject:identifier];
    }
}

@end
