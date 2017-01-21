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
    NSPipe *brewPrefixOutputPipe;
    NSColor *installedColor;
    NSColor *notInstalledColor;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self->installedColor = [NSColor colorWithDeviceRed:0.357 green:0.659 blue:0.192 alpha:1.000];
    self->notInstalledColor = [NSColor colorWithDeviceRed:0.897 green:0.231 blue:0.212 alpha:1.000];
}

- (void)viewWillAppear {
    [self lookForTerminalUtility];
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
 * Searches for the the macdown terminal utility and invokes foundTerminalUtilityAtURL: if found.
 */
- (void)lookForTerminalUtility {
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
            NSString *terminalUtilityDefaultPath = @"/usr/local/bin/macdown";
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:terminalUtilityDefaultPath]) {
                NSURL *terminalUtilityUrl = [NSURL fileURLWithPath:terminalUtilityDefaultPath];
                [self foundTerminalUtilityAtURL:terminalUtilityUrl];
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
            
            NSString *terminalUtilityPath = [output stringByAppendingString:@"/bin/macdown"];
            
            // If MacDown was installed from the Homebrew cask then the macdown binary should exist at this path
            if ([[NSFileManager defaultManager] fileExistsAtPath:terminalUtilityPath]) {
                NSURL *terminalUtilityUrl = [NSURL fileURLWithPath:terminalUtilityPath];
                [self foundTerminalUtilityAtURL:terminalUtilityUrl];
            }
        }
    }
}

- (void)foundTerminalUtilityAtURL:(NSURL *)url {
    [self indicateTerminalUtilityInstalledAt:url];
}

- (void)indicateTerminalUtilityInstalledAt:(NSURL *)url {
    self.supportIndicator.textColor = self->installedColor;
    [self.supportText setStringValue:@"Shell support installed"];
    [self.location setStringValue:url.path];
    [self.installUninstallButton setTitle:@"Uninstall"];
    
    [[NSFontManager sharedFontManager] convertFont:self.location.font toNotHaveTrait:NSFontItalicTrait];
}

- (void)indicateTerminalUtilityNotInstalled {
    self.supportIndicator.textColor = self->notInstalledColor;
    [self.supportText setStringValue:@"Shell support not installed"];
    [self.location setStringValue:@"<Not installed>"];
    [self.installUninstallButton setTitle:@"Install"];
    
    self.location.font = [[NSFontManager sharedFontManager] convertFont:self.location.font toHaveTrait:NSFontItalicTrait];
}

@end
