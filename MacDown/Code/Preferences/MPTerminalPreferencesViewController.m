//
//  MPTerminalPreferencesViewController.m
//  MacDown
//
//  Created by Niklas Berglund on 2017-01-11.
//  Copyright © 2017 Tzu-ping Chung . All rights reserved.
//

#import "MPHomebrewSubprocessController.h"
#import "MPPreferences.h"
#import "MPTerminalPreferencesViewController.h"
#import "MPUtilities.h"

@interface MPTerminalPreferencesViewController ()
@property (weak) IBOutlet NSTextField *supportIndicator;
@property (weak) IBOutlet NSTextField *supportTextField;
@property (weak) IBOutlet NSTextField *infoTextField;
@property (weak) IBOutlet NSTextField *locationTextField;
@property (weak) IBOutlet NSButton *installUninstallButton;
@end

@implementation MPTerminalPreferencesViewController {
    NSURL *shellUtilityURL;
    NSPipe *brewPrefixOutputPipe;
    NSColor *installedColor;
    NSColor *notInstalledColor;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self->installedColor = [NSColor colorWithDeviceRed:0.357 green:0.659 blue:0.192 alpha:1.000];
    self->notInstalledColor = [NSColor colorWithDeviceRed:0.897 green:0.231 blue:0.212 alpha:1.000];
    
    [self highlightMacdownInInfo];
    
    [self.installUninstallButton setTarget:self];
    [self indicateShellUtilityNotInstalled];
}

- (void)viewWillAppear
{
    [self lookForShellUtility];
}

#pragma mark - MASPreferencesViewController

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

#pragma mark - Private methods

/**
 * Searches for the the macdown shell utility and invokes foundShellUtilityAtURL: if found.
 */
- (void)lookForShellUtility
{
    __weak MPTerminalPreferencesViewController *weakSelf = self;
    MPDetectHomebrewPrefixWithCompletionhandler(^(NSString *output) {
        NSString *macdownPath = @"/usr/local/bin/macdown";
        if (output)
        {
            NSCharacterSet *padding =
                [NSCharacterSet whitespaceAndNewlineCharacterSet];
            NSString *prefix = [output stringByTrimmingCharactersInSet:padding];
            macdownPath =
                [prefix stringByAppendingPathComponent:@"bin/macdown"];
        }

        if ([[NSFileManager defaultManager] fileExistsAtPath:macdownPath])
        {
            NSURL *shellUtilityUrl = [NSURL fileURLWithPath:macdownPath];
            [weakSelf foundShellUtilityAtURL:shellUtilityUrl];
        }
    });
}

- (void)foundShellUtilityAtURL:(NSURL *)url
{
    self->shellUtilityURL = url;
    [self indicateShellUtilityInstalledAt:url];
}

- (void)indicateShellUtilityInstalledAt:(NSURL *)url
{
    self.supportIndicator.textColor = self->installedColor;
    [self.supportTextField setStringValue:NSLocalizedString(@"Shell utility installed", @"Label stating that shell utility has been installed")];
    [self.locationTextField setStringValue:url.path];
    NSFont *installedLocationFont = [NSFont fontWithName:@"Menlo" size:self.locationTextField.font.pointSize];
    [self.locationTextField setFont:installedLocationFont];
    [self.installUninstallButton setTitle:NSLocalizedString(@"Uninstall", @"Uninstall shell utility button")];
    [self.installUninstallButton setAction:@selector(unInstallShellUtility)];
}

- (void)indicateShellUtilityNotInstalled
{
    self.supportIndicator.textColor = self->notInstalledColor;
    [self.supportTextField setStringValue:NSLocalizedString(@"Shell utility not installed", @"Label stating that shell utility has not been installed")];
    [self.locationTextField setStringValue:NSLocalizedString(@"<Not installed>", @"Displayed instead of path when shell utility has not been installed")];
    NSFont *notInstalledFont = [[NSFontManager sharedFontManager] convertFont:
                                [NSFont systemFontOfSize:self.locationTextField.font.pointSize]
                                toHaveTrait:NSFontItalicTrait];
    [self.locationTextField setFont:notInstalledFont];
    [self.installUninstallButton setTitle:NSLocalizedString(@"Install", @"Install shell utility button")];
    [self.installUninstallButton setAction:@selector(installShellUtility)];
}

- (void)installShellUtility
{
    // URL for macdown utility in .app bundle
    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *utilityBundleUrl = [[bundle sharedSupportURL] URLByAppendingPathComponent:@"bin/macdown"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[utilityBundleUrl path]])
    {
        NSString *installPath = @"/usr/local/bin/macdown";
        
        NSError *copyError;
        [[NSFileManager defaultManager] copyItemAtPath:utilityBundleUrl.path toPath:installPath error:&copyError];
        
        if (copyError == nil)
        {
            [self lookForShellUtility];
        }
    }
}

- (void)unInstallShellUtility
{
    if (self->shellUtilityURL)
    {
        NSError *removeFileError;
        [[NSFileManager defaultManager] removeItemAtURL:self->shellUtilityURL error:&removeFileError];
        
        if (removeFileError == nil)
        {
            self->shellUtilityURL = nil;
            [self indicateShellUtilityNotInstalled];
        }
    }
}

/**
 * Highlights all occurences of "macdown" in the info-text
 */
- (void)highlightMacdownInInfo
{
    NSString *infoString = self.infoTextField.stringValue;
    NSMutableAttributedString *attributedInfoString = [[NSMutableAttributedString alloc] initWithString:infoString];
    
    NSRange searchRange = NSMakeRange(0, infoString.length);
    CGFloat infoFontSize = self.infoTextField.font.pointSize;
    NSFont *highlightFont = [NSFont fontWithName:@"Menlo" size:infoFontSize];
    
    while (searchRange.location < infoString.length)
    {
        searchRange.length = infoString.length - searchRange.location;
        NSRange foundRange = [infoString rangeOfString:@"macdown" options:NSLiteralSearch range:searchRange];
        
        if (foundRange.location != NSNotFound)
        {
            [attributedInfoString addAttribute:NSFontAttributeName value:highlightFont range:foundRange];
            
            searchRange.location = foundRange.location + foundRange.length;
        }
        else // Found all occurences
        {
            break;
        }
    }
    
    [self.infoTextField setAttributedStringValue:attributedInfoString];
}

@end
