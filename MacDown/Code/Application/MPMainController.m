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
#import "MPUtilities.h"
#import "MPPreferences.h"
#import "MPGeneralPreferencesViewController.h"
#import "MPMarkdownPreferencesViewController.h"
#import "MPEditorPreferencesViewController.h"
#import "MPHtmlPreferencesViewController.h"


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
    NSDocumentController *c =
        [NSDocumentController sharedDocumentController];
    NSURL *source = [[NSBundle mainBundle] URLForResource:@"help"
                                            withExtension:@"md"];
    NSURL *target = [NSURL fileURLWithPathComponents:@[NSTemporaryDirectory(),
                                                       @"help.md"]];
    BOOL ok = NO;
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager removeItemAtURL:target error:NULL];
    ok = [manager copyItemAtURL:source toURL:target error:NULL];
    if (ok)
    {
        [c openDocumentWithContentsOfURL:target display:YES completionHandler:
            ^(NSDocument *document, BOOL wasOpen, NSError *error) {
                if (!document || wasOpen || error)
                    return;
                NSRect frame = [NSScreen mainScreen].visibleFrame;
                for (NSWindowController *wc in document.windowControllers)
                    [wc.window setFrame:frame display:YES];
            }];
    }
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
    [self openPendingFiles];
    return self;
}


#pragma mark - NSApplicationDelegate

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return !self.prefereces.supressesUntitledDocumentOnLaunch;
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
    for (NSString *path in self.prefereces.filesToOpenOnNextLaunch)
    {
        NSURL *url = [NSURL URLWithString:path];
        if ([url checkResourceIsReachableAndReturnError:NULL])
        {
            [c openDocumentWithContentsOfURL:url display:YES
                           completionHandler:NULL];
        }
        else
        {
            NSDocument *doc = [c openUntitledDocumentAndDisplay:YES error:NULL];
            doc.draft = YES;
            doc.fileURL = url;
        }
    }
    self.prefereces.filesToOpenOnNextLaunch = nil;
}


#pragma mark - Notification handler

- (void)showFirstLaunchTips
{
    [self showHelp:nil];
}


@end
