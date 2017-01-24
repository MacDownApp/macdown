//
//  MPEditorPreferencesViewController.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPEditorPreferencesViewController.h"
#import "MPUtilities.h"
#import "MPPreferences.h"


NSString * const MPDidRequestEditorSetupNotificationKeyName =
    @"MPDidRequestEditorSetupNotificationKeyNameKey";


@interface MPEditorPreferencesViewController () <NSTextFieldDelegate>
@property (weak) IBOutlet NSTextField *fontPreviewField;
@property (weak) IBOutlet NSPopUpButton *themeSelect;
@property (weak) IBOutlet NSSegmentedControl *themeFunctions;
@end


@implementation MPEditorPreferencesViewController


#pragma mark - MASPreferencesViewController

- (NSString *)identifier
{
    return @"EditorPreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"PreferencesEditor"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Editor", @"Preference pane title.");
}


#pragma mark - Override

- (void)viewWillAppear
{
    [self refreshPreviewForFont:[self.preferences.editorBaseFont copy]];
    [self loadThemes];
}


#pragma mark - Private

- (void)refreshPreviewForFont:(NSFont *)font
{
    NSString *text = [NSString stringWithFormat:@"%@ - %.1lf",
                      font.displayName, font.pointSize];
    self.fontPreviewField.stringValue = text;
    self.fontPreviewField.font = font;
}

- (void)loadThemes
{
    [self.themeSelect setEnabled:NO];
    [self.themeSelect removeAllItems];

    NSArray *itemTitles = MPListEntriesForDirectory(
        kMPThemesDirectoryName,
        MPFileNameHasExtensionProcessor(kMPThemeFileExtension)
    );

    [self.themeSelect addItemWithTitle:@""];
    [self.themeSelect addItemsWithTitles:itemTitles];

    NSString *title = [self.preferences.editorStyleName copy];
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
    manager.target = self;
    manager.action = @selector(changeFont:);
    [manager setSelectedFont:[self.preferences.editorBaseFont copy]
                  isMultiple:NO];

    NSFontPanel *panel = [manager fontPanel:YES];
    [panel orderFront:sender];
}

- (IBAction)changeTheme:(NSPopUpButton *)sender
{
    NSString *title = sender.selectedItem.title;

    // Special case: the first (empty) item. No stylesheets will be used.
    if (!title.length)
        self.preferences.editorStyleName = nil;
    else
        self.preferences.editorStyleName = title;
}

- (IBAction)invokeStylesheetFunction:(NSSegmentedControl *)sender
{
    switch (sender.selectedSegment)
    {
        case 0:     // Reveal
        {
            NSString *dirPath = MPDataDirectory(kMPThemesDirectoryName);
            NSURL *url = [NSURL fileURLWithPath:dirPath];
            NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
            [workspace activateFileViewerSelectingURLs:@[url]];
            break;
        }
        case 1:     // Reload
        {
            [self loadThemes];
            NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
            NSString *name = MPDidRequestEditorSetupNotificationKeyName;
            NSString *key = NSStringFromSelector(@selector(editorStyleName));
            [center postNotificationName:MPDidRequestEditorSetupNotification
                                  object:self userInfo:@{name: key}];
            break;
        }
        default:
            break;
    }
}

@end
