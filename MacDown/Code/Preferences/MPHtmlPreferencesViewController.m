//
//  MPHtmlPreferencesViewController.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 8/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPHtmlPreferencesViewController.h"
#import "MPUtilities.h"
#import "MPPreferences.h"


@interface MPHtmlPreferencesViewController ()
@property (weak) IBOutlet NSPopUpButton *stylesheetSelect;
@property (weak) IBOutlet NSSegmentedControl *stylesheetFunctions;
@end


@implementation MPHtmlPreferencesViewController

#pragma mark - MASPrefernecesViewController

- (NSString *)identifier
{
    return @"HtmlPreferences";
}

- (NSImage *)toolbarItemImage
{
    // TODO: Give me an icon.
    return [NSImage imageWithSize:NSMakeSize(1.0, 1.0)
                          flipped:NO
                   drawingHandler:nil];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Rendering", @"Preference pane title.");
}


#pragma mark - Override

- (void)viewWillAppear
{
    [self loadStylesheets];
}


#pragma mark - IBAction

- (IBAction)changeStylesheet:(NSPopUpButton *)sender
{
    NSString *title = sender.selectedItem.title;

    // Special case: the first (empty) item. No stylesheets will be used.
    if (!title.length)
        self.preferences.htmlStyleName = nil;
    else
        self.preferences.htmlStyleName = title;
}

- (IBAction)invokeStylesheetFunction:(NSSegmentedControl *)sender
{
    switch (sender.selectedSegment)
    {
        case 0:     // Reveal
        {
            NSString *dirPath = MPDataDirectory(kMPStylesDirectoryName);
            NSURL *url = [NSURL fileURLWithPath:dirPath];
            NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
            [workspace activateFileViewerSelectingURLs:@[url]];
            break;
        }
        case 1:     // Reload
            [self loadStylesheets];
            break;
        default:
            break;
    }
}


#pragma mark - Private

- (void)loadStylesheets
{
    [self.stylesheetSelect setEnabled:NO];
    [self.stylesheetSelect removeAllItems];

    NSArray *itemTitles = MPListEntriesForDirectory(
        kMPStylesDirectoryName,
        MPFileNameHasSuffixProcessor(kMPStyleFileExtension)
    );

    [self.stylesheetSelect addItemWithTitle:@""];
    [self.stylesheetSelect addItemsWithTitles:itemTitles];

    NSString *title = [self.preferences.htmlStyleName copy];
    if (title.length)
        [self.stylesheetSelect selectItemWithTitle:title];

    [self.stylesheetSelect setEnabled:YES];
}

@end
