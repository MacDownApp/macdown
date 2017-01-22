//
//  MPTerminalPreferencesViewController.m
//  MacDown
//
//  Created by Niklas Berglund on 2017-01-11.
//  Copyright © 2017 Tzu-ping Chung . All rights reserved.
//

#import "MPTerminalPreferencesViewController.h"
#import "MPUtilities.h"
#import "MPPreferences.h"

@interface MPTerminalPreferencesViewController ()

@end

@implementation MPTerminalPreferencesViewController {
    NSURL *shellUtilityURL;
    NSPipe *brewPrefixOutputPipe;
    NSColor *installedColor;
    NSColor *notInstalledColor;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self->installedColor = [NSColor colorWithDeviceRed:0.357 green:0.659 blue:0.192 alpha:1.000];
    self->notInstalledColor = [NSColor colorWithDeviceRed:0.897 green:0.231 blue:0.212 alpha:1.000];
    
    [self.installUninstallButton setTarget:self];
    [self indicateShellUtilityNotInstalled];
}

- (void)viewWillAppear {
    [self lookForShellUtility];
}

#pragma mark - MASPrefernecesViewController

- (NSString *)identifier
{
    return @"TerminalPreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"PreferencesTerminal"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Terminal", @"Preference pane title.");
}

/**
 * Searches for the the macdown shell utility and invokes foundShellUtilityAtURL: if found.
 */
- (void)lookForShellUtility {
    NSTask *brewPrefixTask = [NSTask new];
    [brewPrefixTask setLaunchPath:@"brew"];
    [brewPrefixTask setArguments:@[@"--prefix"]];
    self->brewPrefixOutputPipe = [NSPipe pipe];
    [brewPrefixTask setStandardOutput:self->brewPrefixOutputPipe];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(brewPrefixReadCompleted:) name:NSFileHandleReadToEndOfFileCompletionNotification object:[self->brewPrefixOutputPipe fileHandleForReading]];
    [[self->brewPrefixOutputPipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
    
    @try {
        [brewPrefixTask launch];
    }
    @catch (NSException *exception) { // Homebrew not installed
        if ([exception.name isEqualToString:NSInvalidArgumentException]) {
            // If installed through DMG the macdown binary should be here
            NSString *shellUtilityDefaultPath = @"/usr/local/bin/macdown";
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:shellUtilityDefaultPath]) {
                NSURL *shellUtilityUrl = [NSURL fileURLWithPath:shellUtilityDefaultPath];
                [self foundShellUtilityAtURL:shellUtilityUrl];
            }
        }
    }
}

- (void)brewPrefixReadCompleted:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:[notification object]];
    
    if ([notification object]) {
        NSFileHandle *fileHandle = [notification object];
        
        if (fileHandle == self->brewPrefixOutputPipe.fileHandleForReading) {
            NSString *output = [[NSString alloc] initWithData:[[notification userInfo] objectForKey:NSFileHandleNotificationDataItem] encoding:NSUTF8StringEncoding];
            output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            NSString *shellUtilityPath = [output stringByAppendingString:@"/bin/macdown"];
            
            // If MacDown was installed from the Homebrew cask then the macdown binary should exist at this path
            if ([[NSFileManager defaultManager] fileExistsAtPath:shellUtilityPath]) {
                NSURL *shellUtilityUrl = [NSURL fileURLWithPath:shellUtilityPath];
                [self foundShellUtilityAtURL:shellUtilityUrl];
            }
        }
    }
}

- (void)foundShellUtilityAtURL:(NSURL *)url {
    self->shellUtilityURL = url;
    [self indicateShellUtilityInstalledAt:url];
}

- (void)indicateShellUtilityInstalledAt:(NSURL *)url {
    self.supportIndicator.textColor = self->installedColor;
    [self.supportText setStringValue:@"Shell support installed"];
    [self.location setStringValue:url.path];
    [self.installUninstallButton setTitle:@"Uninstall"];
    [self.installUninstallButton setAction:@selector(unInstallShellUtility)];
    
    [[NSFontManager sharedFontManager] convertFont:self.location.font toNotHaveTrait:NSFontItalicTrait];
}

- (void)indicateShellUtilityNotInstalled {
    self.supportIndicator.textColor = self->notInstalledColor;
    [self.supportText setStringValue:@"Shell support not installed"];
    [self.location setStringValue:@"<Not installed>"];
    [self.installUninstallButton setTitle:@"Install"];
    [self.installUninstallButton setAction:@selector(installShellUtility)];
    
    self.location.font = [[NSFontManager sharedFontManager] convertFont:self.location.font toHaveTrait:NSFontItalicTrait];
}

- (void)installShellUtility {
    // URL for macdown utility in .app bundle
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *utilityBundleUrl = [[bundle sharedSupportURL] URLByAppendingPathComponent:@"bin/macdown"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[utilityBundleUrl path]]) {
        NSString *installPath = @"/usr/local/bin/macdown";
        
        NSError *copyError;
        [[NSFileManager defaultManager] copyItemAtPath:utilityBundleUrl.path toPath:installPath error:&copyError];
        
        if (copyError == nil) {
            [self lookForShellUtility];
        }
    }
}

- (void)unInstallShellUtility {
    if (self->shellUtilityURL) {
        NSError *removeFileError;
        [[NSFileManager defaultManager] removeItemAtURL:self->shellUtilityURL error:&removeFileError];
        
        if (removeFileError == nil) {
            self->shellUtilityURL = nil;
            [self indicateShellUtilityNotInstalled];
        }
    }
}

@end
