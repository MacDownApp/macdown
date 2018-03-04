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
@property (assign) BOOL supressesUntitledDocumentOnLaunch;
@property (assign) BOOL createFileForLinkTarget;

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
@property (assign) BOOL editorAutoIncrementNumberedLists;
@property (assign) BOOL editorConvertTabs;
@property (assign) BOOL editorInsertPrefixInBlock;
@property (assign) BOOL editorCompleteMatchingCharacters;
@property (assign) BOOL editorSyncScrolling;
@property (assign) BOOL editorSmartHome;
@property (assign) NSString *editorStyleName;
@property (assign) CGFloat editorHorizontalInset;
@property (assign) CGFloat editorVerticalInset;
@property (assign) CGFloat editorLineSpacing;
@property (assign) BOOL editorWidthLimited;
@property (assign) CGFloat editorMaximumWidth;
@property (assign) BOOL editorOnRight;
@property (assign) BOOL editorShowWordCount;
@property (assign) NSInteger editorWordCountType;
@property (assign) BOOL editorScrollsPastEnd;
@property (assign) BOOL editorEnsuresNewlineAtEndOfFile;
@property (assign) NSInteger editorUnorderedListMarkerType;

@property (assign) BOOL previewZoomRelativeToBaseFontSize;

@property (assign) NSString *htmlTemplateName;
@property (assign) NSString *htmlStyleName;
@property (assign) BOOL htmlDetectFrontMatter;
@property (assign) BOOL htmlTaskList;
@property (assign) BOOL htmlHardWrap;
@property (assign) BOOL htmlMathJax;
@property (assign) BOOL htmlMathJaxInlineDollar;
@property (assign) BOOL htmlSyntaxHighlighting;
@property (assign) NSString *htmlHighlightingThemeName;
@property (assign) BOOL htmlLineNumbers;
@property (assign) BOOL htmlGraphviz;
@property (assign) BOOL htmlMermaid;
@property (assign) NSInteger htmlCodeBlockAccessory;
@property (assign) NSURL *htmlDefaultDirectoryUrl;
@property (assign) BOOL htmlRendersTOC;

// Calculated values.
@property (readonly) NSString *editorBaseFontName;
@property (readonly) CGFloat editorBaseFontSize;
@property (nonatomic, assign) NSFont *editorBaseFont;
@property (readonly) NSString *editorUnorderedListMarker;

- (instancetype)init;

// Convinience methods.
@property (nonatomic, assign) NSArray *filesToOpen;
@property (nonatomic, assign) NSString *pipedContentFileToOpen;

@end
