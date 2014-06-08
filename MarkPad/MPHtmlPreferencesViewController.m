//
//  MPHtmlPreferencesViewController.m
//  MarkPad
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
    return NSLocalizedString(@"HTML", @"Preference pane title.");
}


#pragma mark - Override

- (void)viewWillAppear
{
    [self reloadStylesheets];
}


#pragma mark - IBAction

- (IBAction)changeStylesheet:(NSPopUpButton *)sender
{
    NSString *title = sender.selectedItem.title;

    // Special case: the first (empty) item. No stylesheets will be used.
    if (!title.length)
    {
        [self.stylesheetFunctions setEnabled:NO forSegment:0];
        self.preferences.htmlStyleName = nil;
    }
    else
    {
        [self.stylesheetFunctions setEnabled:YES forSegment:0];
        self.preferences.htmlStyleName = title;
    }
}

- (IBAction)invokeStylesheetFunction:(NSSegmentedControl *)sender
{
    switch (sender.selectedSegment)
    {
        case 0:     // Reveal
        {
            NSString *dirPath = MPGetDataDirectoryPath(MPStylesDirectoryName);
            NSURL *url = [NSURL fileURLWithPath:dirPath];
            NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
            [workspace activateFileViewerSelectingURLs:@[url]];
            break;
        }
        case 1:     // Reload
            [self reloadStylesheets];
            break;
        default:
            break;
    }
}


#pragma mark - Private

- (void)reloadStylesheets
{
    [self.stylesheetSelect setEnabled:NO];

    [self.stylesheetSelect removeAllItems];
    NSString *dirPath = MPGetDataDirectoryPath(MPStylesDirectoryName);

    NSError *error = nil;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *fileNames = [manager contentsOfDirectoryAtPath:dirPath
                                                      error:&error];
    if (error || !fileNames.count)
        return;

    [self.stylesheetSelect addItemWithTitle:@""];
    for (NSString *fileName in fileNames)
    {
        NSString *absPath = [NSString pathWithComponents:@[dirPath, fileName]];
        if ([fileName hasSuffix:MPStyleFileExtension]
            && [manager fileExistsAtPath:absPath isDirectory:NO])
        {
            NSUInteger end = fileName.length - MPStyleFileExtension.length;
            NSString *title = [fileName substringToIndex:end];
            [self.stylesheetSelect addItemWithTitle:title];
        }
    }

    NSString *title = self.preferences.htmlStyleName;
    if (title.length)
        [self.stylesheetSelect selectItemWithTitle:title];

    [self.stylesheetSelect setEnabled:YES];
}

@end
