//
//  MPPreferences.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPPreferences.h"

static NSString * const MPPreferencesDidSynchronizeNotificationName =
    @"MPPreferencesDidSynchronizeNotificationName";


@interface MPPreferences ()
@property (nonatomic, weak) NSDictionary *editorBaseFontInfo;
@end


@implementation MPPreferences

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    NSString *version =
        [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];

    // This is a fresh install without preferences. Set default preferences.
    if (!self.firstVersionInstalled)
    {
        self.firstVersionInstalled = version;
        self.extensionIntraEmphasis = YES;
        self.extensionTables = YES;
        self.extensionFencedCode = YES;
        self.extensionFootnotes = YES;
        self.editorBaseFontInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            @"Menlo-Regular", @"name",
            @(12.0), @"size",
        nil];
    }
    [self editorBaseFont];
    self.latestVersionInstalled = version;    return self;
}


#pragma mark - Accessors

@dynamic firstVersionInstalled;
@dynamic latestVersionInstalled;

@dynamic extensionIntraEmphasis;
@dynamic extensionTables;
@dynamic extensionFencedCode;
@dynamic extensionAutolink;
@dynamic extensionStrikeThough;
@dynamic extensionUnderline;
@dynamic extensionSuperscript;
@dynamic extensionHighlight;
@dynamic extensionFootnotes;
@dynamic extensionQuote;
@dynamic extensionSmartyPants;

@dynamic editorConvertTabs;
@dynamic editorSyncScrolling;
@dynamic editorStyleName;
@dynamic editorHorizontalInset;
@dynamic editorVerticalInset;

@dynamic htmlStyleName;

// Private preference.
@dynamic editorBaseFontInfo;

- (NSFont *)editorBaseFont
{
    NSDictionary *info = self.editorBaseFontInfo;
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

@end
