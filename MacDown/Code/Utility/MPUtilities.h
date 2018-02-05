//
//  MPUtilities.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 8/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const kMPStylesDirectoryName;
extern NSString * const kMPStyleFileExtension;
extern NSString * const kMPThemesDirectoryName;
extern NSString * const kMPThemeFileExtension;
extern NSString * const kMPPlugInsDirectoryName;
extern NSString * const kMPPlugInFileExtension;

extern const NSTouchBarItemIdentifier MPTouchBarItemFormattingIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemStrongIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemEmphasisIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemUnderlineIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemCodeIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemCommentIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemBlockquoteIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemStrikeIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemHighlightIdentifier;

extern const NSTouchBarItemIdentifier MPTouchBarItemHeadingPopIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH1Identifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH2Identifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH3Identifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH4Identifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH5Identifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH6Identifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH0Identifier;

extern const NSTouchBarItemIdentifier MPTouchBarItemLinkIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemImageIdentifier;

extern const NSTouchBarItemIdentifier MPTouchBarItemListsIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemOrderedListIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemSimpleListIdentifier;

extern const NSTouchBarItemIdentifier MPTouchBarItemShiftIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemShiftRightIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemShiftLeftIdentifier;

extern const NSTouchBarItemIdentifier MPTouchBarItemCopyHTMLIdentifier;

extern const NSTouchBarItemIdentifier MPTouchBarItemLayoutPopIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemLayoutIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemHideEditorIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemEqualSplitEditorIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemHidePreviewIdentifier;

NSString *MPDataDirectory(NSString *relativePath);
NSString *MPPathToDataFile(NSString *name, NSString *dirPath);

NSArray *MPListEntriesForDirectory(
    NSString *dirName, NSString *(^processor)(NSString *absolutePath)
);

// Block factory for MPListEntriesForDirectory
NSString *(^MPFileNameHasExtensionProcessor(NSString *ext))(NSString *path);

BOOL MPCharacterIsWhitespace(unichar character);
BOOL MPCharacterIsNewline(unichar character);
BOOL MPStringIsNewline(NSString *str);

NSString *MPStylePathForName(NSString *name);
NSString *MPThemePathForName(NSString *name);
NSURL *MPHighlightingThemeURLForName(NSString *name);
NSString *MPReadFileOfPath(NSString *path);

NSDictionary *MPGetDataMap(NSString *name);

id MPGetObjectFromJavaScript(NSString *code, NSString *variableName);


static void (^MPDocumentOpenCompletionEmpty)(
        NSDocument *doc, BOOL wasOpen, NSError *error) = ^(
        NSDocument *doc, BOOL wasOpen, NSError *error) {

};
