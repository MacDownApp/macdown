//
//  MPPreferences.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <PAPreferences/PAPreferences.h>


extern NSString * const MPDidDetectFreshInstallationNotification;

@interface MPPreferences : PAPreferences

@property (assign) NSString *firstVersionInstalled;
@property (assign) NSString *latestVersionInstalled;
@property (assign) BOOL updateIncludesPreReleases;

// Extension flags.
@property (assign) BOOL extensionIntraEmphasis;
@property (assign) BOOL extensionTables;
@property (assign) BOOL extensionFencedCode;
@property (assign) BOOL extensionAutolink;
@property (assign) BOOL extensionStrikethough;
@property (assign) BOOL extensionUnderline;
@property (assign) BOOL extensionSuperscript;
@property (assign) BOOL extensionHighlight;
@property (assign) BOOL extensionFootnotes;
@property (assign) BOOL extensionQuote;
@property (assign) BOOL extensionSmartyPants;

@property (assign) BOOL markdownManualRender;

@property (assign) NSDictionary *editorBaseFontInfo;
@property (assign) BOOL editorConvertTabs;
@property (assign) BOOL editorCompleteMatchingCharacters;
@property (assign) BOOL editorSyncScrolling;
@property (assign) BOOL editorSmartHome;
@property (assign) NSString *editorStyleName;
@property (assign) CGFloat editorHorizontalInset;
@property (assign) CGFloat editorVerticalInset;
@property (assign) CGFloat editorLineSpacing;
@property (assign) BOOL editorOnRight;
@property (assign) BOOL editorShowWordCount;
@property (assign) NSInteger editorWordCountType;

@property (assign) NSString *htmlStyleName;
@property (assign) BOOL htmlTaskList;
@property (assign) BOOL htmlHardWrap;
@property (assign) BOOL htmlMathJax;
@property (assign) BOOL htmlMathJaxInlineDollar;
@property (assign) BOOL htmlSyntaxHighlighting;
@property (assign) NSString *htmlHighlightingThemeName;
@property (assign) NSURL *htmlDefaultDirectoryUrl;

// Calculated values.
@property (nonatomic, assign) NSFont *editorBaseFont;

- (instancetype)init;

@end
