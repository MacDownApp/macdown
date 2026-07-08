//
//  MPGeneralPreferencesViewController.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 01/7.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//
//  Portions Copyright (c) 2026 Roberto Bissanti.
//

#import "MPGeneralPreferencesViewController.h"
#import "MPPreferences.h"


@interface MPGeneralPreferencesViewController ()
@property (weak) IBOutlet NSButton *autoRenderingToggle;
@end


@implementation MPGeneralPreferencesViewController

#pragma mark - MASPreferencesViewController

- (NSString *)viewIdentifier
{
    return @"GeneralPreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"PreferencesGeneral"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"General", @"Preference pane title.");
}


#pragma mark - IBAction

- (IBAction)updateWordCounterVisibility:(id)sender
{
    if (sender == self.autoRenderingToggle)
    {
        if (self.autoRenderingToggle.state != NSControlStateValueOn)
            self.preferences.editorShowWordCount = NO;
    }
}

@end
