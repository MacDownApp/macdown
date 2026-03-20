//
//  MPGeneralPreferencesViewController.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 01/7.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPGeneralPreferencesViewController.h"
#import "MPPreferences.h"


@interface MPGeneralPreferencesViewController ()
@property (weak) IBOutlet NSButton *autoRenderingToggle;
@property (weak) IBOutlet NSPopUpButton *defaultViewModePopup;
@property (weak) IBOutlet NSPopUpButton *openedFileViewModePopup;
@end


@implementation MPGeneralPreferencesViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.defaultViewModePopup selectItemWithTag:self.preferences.defaultViewMode];
    [self.openedFileViewModePopup selectItemWithTag:self.preferences.openedFileViewMode];
}

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

- (IBAction)defaultViewModeChanged:(id)sender
{
    self.preferences.defaultViewMode = self.defaultViewModePopup.selectedTag;
}

- (IBAction)openedFileViewModeChanged:(id)sender
{
    self.preferences.openedFileViewMode = self.openedFileViewModePopup.selectedTag;
}

- (IBAction)updateWordCounterVisibility:(id)sender
{
    if (sender == self.autoRenderingToggle)
    {
        if (self.autoRenderingToggle.state != NSOnState)
            self.preferences.editorShowWordCount = NO;
    }
}

@end
