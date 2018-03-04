//
//  MPPreferences.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPPreferences.h"
#import "NSUserDefaults+Suite.h"
#import "MPGlobals.h"


typedef NS_ENUM(NSUInteger, MPUnorderedListMarkerType)
{
    MPUnorderedListMarkerAsterisk = 0,
    MPUnorderedListMarkerPlusSign = 1,
    MPUnorderedListMarkerMinusSign = 2,
};



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
@dynamic supressesUntitledDocumentOnLaunch;
@dynamic createFileForLinkTarget;

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
@dynamic editorInsertPrefixInBlock;
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
@dynamic editorUnorderedListMarkerType;

@dynamic previewZoomRelativeToBaseFontSize;

@dynamic htmlTemplateName;
@dynamic htmlStyleName;
@dynamic htmlDetectFrontMatter;
@dynamic htmlTaskList;
@dynamic htmlHardWrap;
@dynamic htmlMathJax;
@dynamic htmlMathJaxInlineDollar;
@dynamic htmlSyntaxHighlighting;
@dynamic htmlDefaultDirectoryUrl;
@dynamic htmlHighlightingThemeName;
@dynamic htmlLineNumbers;
@dynamic htmlGraphviz;
@dynamic htmlMermaid;
@dynamic htmlCodeBlockAccessory;
@dynamic htmlRendersTOC;

// Private preference.
@dynamic editorBaseFontInfo;

- (NSString *)editorBaseFontName
{
    return [self.editorBaseFontInfo[kMPDefaultEditorFontNameKey] copy];
}

- (CGFloat)editorBaseFontSize
{
    NSDictionary *info = self.editorBaseFontInfo;
    return [info[kMPDefaultEditorFontPointSizeKey] doubleValue];
}

- (NSFont *)editorBaseFont
{
    return [NSFont fontWithName:self.editorBaseFontName
                           size:self.editorBaseFontSize];
}

- (void)setEditorBaseFont:(NSFont *)font
{
    NSDictionary *info = @{
        kMPDefaultEditorFontNameKey: font.fontName,
        kMPDefaultEditorFontPointSizeKey: @(font.pointSize)
    };
    self.editorBaseFontInfo = info;
}

- (NSString *)editorUnorderedListMarker
{
    switch (self.editorUnorderedListMarkerType)
    {
        case MPUnorderedListMarkerAsterisk:
            return @"* ";
        case MPUnorderedListMarkerPlusSign:
            return @"+ ";
        case MPUnorderedListMarkerMinusSign:
            return @"- ";
        default:
            return @"* ";
    }
}

- (NSArray *)filesToOpen
{
    return [self.userDefaults objectForKey:kMPFilesToOpenKey
                              inSuiteNamed:kMPApplicationSuiteName];
}

- (void)setFilesToOpen:(NSArray *)filesToOpen
{
    [self.userDefaults setObject:filesToOpen
                          forKey:kMPFilesToOpenKey
                    inSuiteNamed:kMPApplicationSuiteName];
}

- (NSString *)pipedContentFileToOpen {
    return [self.userDefaults objectForKey:kMPPipedContentFileToOpen
                              inSuiteNamed:kMPApplicationSuiteName];
}

- (void)setPipedContentFileToOpen:(NSString *)pipedContentFileToOpenPath {
    [self.userDefaults setObject:pipedContentFileToOpenPath
                          forKey:kMPPipedContentFileToOpen
                    inSuiteNamed:kMPApplicationSuiteName];
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

/** Load app-default preferences on first launch.
 *
 * Preferences that need to be initialized manually are put here, and will be
 * applied when the user launches MacDown the first time.
 *
 * Avoid putting preferences that doe not need initialization here. E.g. a
 * boolean preference defaults to `NO` implicitly (because `nil.booleanValue` is
 * `NO` in Objective-C), thus does not need initialization.
 *
 * Note that since this is called only when the user launches the app the first
 * time, new preferences that breaks backward compatibility should NOT be put
 * here. An example would be adding a boolean config to turn OFF an existing
 * functionality. If you add the defualt-loading code here, existing users
 * upgrading from an old version will not have this method invoked, thus
 * effecting app behavior.
 *
 * @see -loadDefaultUserDefaults
 */
- (void)loadDefaultPreferences
{
    self.extensionIntraEmphasis = YES;
    self.extensionTables = YES;
    self.extensionFencedCode = YES;
    self.extensionFootnotes = YES;
    self.editorBaseFontInfo = @{
        kMPDefaultEditorFontNameKey: kMPDefaultEditorFontName,
        kMPDefaultEditorFontPointSizeKey: @(kMPDefaultEditorFontPointSize),
    };
    self.editorStyleName = kMPDefaultEditorThemeName;
    self.editorHorizontalInset = kMPDefaultEditorHorizontalInset;
    self.editorVerticalInset = kMPDefaultEditorVerticalInset;
    self.editorLineSpacing = kMPDefaultEditorLineSpacing;
    self.editorSyncScrolling = kMPDefaultEditorSyncScrolling;
    self.htmlStyleName = kMPDefaultHtmlStyleName;
    self.htmlDefaultDirectoryUrl = [NSURL fileURLWithPath:NSHomeDirectory()
                                              isDirectory:YES];
}

/** Load default preferences when the app launches.
 *
 * Preferences that need to be initialized manually are put here, and will be
 * applied when the user launches MacDown.
 *
 * This differs from -loadDefaultPreferences in that it is invoked *every time*
 * MacDown is launched, making it suitable to perform backward-compatibility
 * checks.
 *
 * @see -loadDefaultPreferences
 */
- (void)loadDefaultUserDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults objectForKey:@"editorMaximumWidth"])
        self.editorMaximumWidth = 1000.0;
    if (![defaults objectForKey:@"editorAutoIncrementNumberedLists"])
        self.editorAutoIncrementNumberedLists = YES;
    if (![defaults objectForKey:@"editorInsertPrefixInBlock"])
        self.editorInsertPrefixInBlock = YES;
    if (![defaults objectForKey:@"htmlTemplateName"])
        self.htmlTemplateName = @"Default";
}

@end
