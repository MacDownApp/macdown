//
//  MPEditorPreferencesViewController.m
//  MarkPad
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPEditorPreferencesViewController.h"
#import "MPUtilities.h"
#import "MPPreferences.h"


@interface MPEditorPreferencesViewController () <NSTextFieldDelegate>
@property (weak) IBOutlet NSTextField *fontPreviewField;
@property (weak) IBOutlet NSPopUpButton *themeSelect;
@property (weak) IBOutlet NSSegmentedControl *themeFunctions;
@end


@implementation MPEditorPreferencesViewController


#pragma mark - MASPrefernecesViewController

- (NSString *)identifier
{
    return @"EditorPreferences";
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
    return NSLocalizedString(@"Editor", @"Preference pane title.");
}


#pragma mark - Override

- (void)viewWillAppear
{
    [self refreshPreviewForFont:self.preferences.editorBaseFont];
    [self reloadThemes];
}


#pragma mark - Private

- (void)refreshPreviewForFont:(NSFont *)font
{
    NSString *text = [NSString stringWithFormat:@"%@ - %.1lf",
                      font.displayName, font.pointSize];
    self.fontPreviewField.stringValue = text;
    self.fontPreviewField.font = font;
}

- (void)reloadThemes
{
    [self.themeSelect setEnabled:NO];

    [self.themeSelect removeAllItems];
    NSString *dirPath = MPGetDataDirectoryPath(MPThemesDirectoryName);

    NSError *error = nil;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *fileNames = [manager contentsOfDirectoryAtPath:dirPath
                                                      error:&error];
    if (error || !fileNames.count)
        return;

    [self.themeSelect addItemWithTitle:@""];
    for (NSString *fileName in fileNames)
    {
        NSString *absPath = [NSString pathWithComponents:@[dirPath, fileName]];
        if ([fileName hasSuffix:MPThemeFileExtension]
            && [manager fileExistsAtPath:absPath isDirectory:NO])
        {
            NSUInteger end = fileName.length - MPThemeFileExtension.length;
            NSString *title = [fileName substringToIndex:end];
            [self.themeSelect addItemWithTitle:title];
        }
    }

    NSString *title = self.preferences.editorStyleName;
    if (title.length)
        [self.themeSelect selectItemWithTitle:title];

    [self.themeSelect setEnabled:YES];
}


#pragma mark - NSFontManager Delegate

- (void)changeFont:(NSFontManager *)sender
{
    NSFont *font = [sender convertFont:sender.selectedFont];
    [self refreshPreviewForFont:font];
    self.preferences.editorBaseFont = font;
}


#pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    if (!fieldEditor.string.length)
        fieldEditor.string = @"0";
    return YES;
}


#pragma mark - IBAction

- (IBAction)showFontPanel:(id)sender
{
    NSFontManager *manager = [NSFontManager sharedFontManager];
    manager.action = @selector(changeFont:);
    [manager setSelectedFont:self.preferences.editorBaseFont isMultiple:NO];

    NSFontPanel *panel = [manager fontPanel:YES];
    [panel orderFront:sender];
}

- (IBAction)changeTheme:(NSPopUpButton *)sender
{
    NSString *title = sender.selectedItem.title;

    // Special case: the first (empty) item. No stylesheets will be used.
    if (!title.length)
    {
        [self.themeFunctions setEnabled:NO forSegment:0];
        self.preferences.editorStyleName = nil;
    }
    else
    {
        [self.themeFunctions setEnabled:YES forSegment:0];
        self.preferences.editorStyleName = title;
    }
}

- (IBAction)invokeStylesheetFunction:(NSSegmentedControl *)sender
{
    switch (sender.selectedSegment)
    {
        case 0:     // Reveal
        {
            NSString *dirPath = MPGetDataDirectoryPath(MPThemesDirectoryName);
            NSURL *url = [NSURL fileURLWithPath:dirPath];
            NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
            [workspace activateFileViewerSelectingURLs:@[url]];
            break;
        }
        case 1:     // Reload
            [self reloadThemes];
            break;
        default:
            break;
    }
}

@end
