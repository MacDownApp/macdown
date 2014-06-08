//
//  MPPreferences.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "PAPreferences.h"

@interface MPPreferences : PAPreferences

@property (nonatomic, weak) NSString *firstVersionInstalled;
@property (nonatomic, weak) NSString *latestVersionInstalled;

// Extension flags.
@property (nonatomic, assign) BOOL extensionIntraEmphasis;
@property (nonatomic, assign) BOOL extensionTables;
@property (nonatomic, assign) BOOL extensionFencedCode;
@property (nonatomic, assign) BOOL extensionAutolink;
@property (nonatomic, assign) BOOL extensionStrikeThough;
@property (nonatomic, assign) BOOL extensionUnderline;
@property (nonatomic, assign) BOOL extensionSuperscript;
@property (nonatomic, assign) BOOL extensionHighlight;
@property (nonatomic, assign) BOOL extensionFootnotes;
@property (nonatomic, assign) BOOL extensionQuote;
@property (nonatomic, assign) BOOL extensionSmartyPants;

@property (nonatomic, assign) BOOL editorConvertTabs;
@property (nonatomic, assign) BOOL editorSyncScrolling;
@property (nonatomic, weak) NSString *editorStyleName;
@property (nonatomic, assign) CGFloat editorHorizontalInset;
@property (nonatomic, assign) CGFloat editorVerticalInset;

@property (nonatomic, weak) NSString *htmlStyleName;

// Calculated values.
@property (nonatomic, unsafe_unretained) NSFont *editorBaseFont;

- (instancetype)init;

@end
