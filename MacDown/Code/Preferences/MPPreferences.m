//
//  MPPreferences.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPPreferences.h"


NSString * const MPDidDetectFreshInstallationNotification =
    @"MPDidDetectFreshInstallationNotificationName";

static NSString * const kMPDefaultEditorFontNameKey = @"name";
static NSString * const kMPDefaultEditorFontPointSizeKey = @"size";
static NSString * const kMPDefaultEditorFontName = @"Menlo-Regular";
static CGFloat    const kMPDefaultEditorFontPointSize = 14.0;
static CGFloat    const kMPDefaultEditorHorizontalInset = 15.0;
static CGFloat    const kMPDefaultEditorVerticalInset = 30.0;
static CGFloat    const kMPDefaultEditorLineSpacing = 3.0;
static BOOL       const kMPDefaultEditorSyncScrolling = YES;
static NSString * const kMPDefaultEditorThemeName = @"Tomorrow+";
static NSString * const kMPDefaultHtmlStyleName = @"GitHub2";


@implementation MPPreferences

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    [self cleanupObsoleteAutosaveValues];

    NSString *version =
        [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];

    // This is a fresh install. Set default preferences.
    if (!self.firstVersionInstalled)
    {
        self.firstVersionInstalled = version;
        [self loadDefaultPreferences];

        // Post this after the initializer finishes to give others to listen
        // to this on construction.
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSNotificationCenter *c = [NSNotificationCenter defaultCenter];
            [c postNotificationName:MPDidDetectFreshInstallationNotification
                             object:self];
        }];
    }
    [self loadDefaultUserDefaults];
    self.latestVersionInstalled = version;
    return self;
}


#pragma mark - Accessors

@dynamic firstVersionInstalled;
@dynamic latestVersionInstalled;
@dynamic updateIncludesPreReleases;

@dynamic extensionIntraEmphasis;
@dynamic extensionTables;
@dynamic extensionFencedCode;
@dynamic extensionAutolink;
@dynamic extensionStrikethough;
@dynamic extensionUnderline;
@dynamic extensionSuperscript;
@dynamic extensionHighlight;
@dynamic extensionFootnotes;
@dynamic extensionQuote;
@dynamic extensionSmartyPants;

@dynamic markdownManualRender;

@dynamic editorAutoIncrementNumberedLists;
@dynamic editorConvertTabs;
@dynamic editorCompleteMatchingCharacters;
@dynamic editorSyncScrolling;
@dynamic editorSmartHome;
@dynamic editorStyleName;
@dynamic editorHorizontalInset;
@dynamic editorVerticalInset;
@dynamic editorLineSpacing;
@dynamic editorWidthLimited;
@dynamic editorMaximumWidth;
@dynamic editorOnRight;
@dynamic editorShowWordCount;
@dynamic editorWordCountType;
@dynamic editorScrollsPastEnd;
@dynamic editorEnsuresNewlineAtEndOfFile;

@dynamic htmlStyleName;
@dynamic htmlDetectFrontMatter;
@dynamic htmlTaskList;
@dynamic htmlHardWrap;
@dynamic htmlKatex;
@dynamic htmlKatexInlineDollar;
@dynamic htmlSyntaxHighlighting;
@dynamic htmlDefaultDirectoryUrl;
@dynamic htmlHighlightingThemeName;

// Private preference.
@dynamic editorBaseFontInfo;

- (NSFont *)editorBaseFont
{
    NSDictionary *info = [self.editorBaseFontInfo copy];
    NSFont *font = [NSFont fontWithName:info[@"name"]
                                   size:[info[@"size"] doubleValue]];
    return font;
}

- (void)setEditorBaseFont:(NSFont *)font
{
    NSDictionary *info =
        @{@"name": font.fontName, @"size": @(font.pointSize)};
    self.editorBaseFontInfo = info;
}


#pragma mark - Private

- (void)cleanupObsoleteAutosaveValues
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *keysToRemove = [NSMutableArray array];
    for (NSString *key in defaults.dictionaryRepresentation)
    {
        for (NSString *p in @[@"NSSplitView Subview Frames", @"NSWindow Frame"])
        {
            if (![key hasPrefix:p] || key.length < p.length + 1)
                continue;
            NSString *path = [key substringFromIndex:p.length + 1];
            NSURL *url = [NSURL URLWithString:path];
            if (!url.isFileURL)
                continue;

            NSFileManager *manager = [NSFileManager defaultManager];
            if (![manager fileExistsAtPath:url.path])
                [keysToRemove addObject:key];
            break;
        }
    }
    for (NSString *key in keysToRemove)
        [defaults removeObjectForKey:key];
}

- (void)loadDefaultPreferences
{
    self.extensionIntraEmphasis = YES;
    self.extensionTables = YES;
    self.extensionFencedCode = YES;
    self.extensionFootnotes = YES;
    self.editorBaseFontInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        kMPDefaultEditorFontName, kMPDefaultEditorFontNameKey,
        @(kMPDefaultEditorFontPointSize), kMPDefaultEditorFontPointSizeKey,
    nil];
    self.editorStyleName = kMPDefaultEditorThemeName;
    self.editorHorizontalInset = kMPDefaultEditorHorizontalInset;
    self.editorVerticalInset = kMPDefaultEditorVerticalInset;
    self.editorLineSpacing = kMPDefaultEditorLineSpacing;
    self.editorSyncScrolling = kMPDefaultEditorSyncScrolling;
    self.editorOnRight = NO;
    self.editorShowWordCount = NO;
    self.editorWordCountType = 0;
    self.htmlStyleName = kMPDefaultHtmlStyleName;
    self.htmlDefaultDirectoryUrl = [NSURL fileURLWithPath:NSHomeDirectory()
                                              isDirectory:YES];
}

- (void)loadDefaultUserDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults objectForKey:@"editorMaximumWidth"])
        self.editorMaximumWidth = 1000.0;
    if (![defaults objectForKey:@"editorAutoIncrementNumberedLists"])
        self.editorAutoIncrementNumberedLists = YES;
}

@end
