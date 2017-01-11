//
//  MPEditorView.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 30/8.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MPEditorView : NSTextView

extern const NSTouchBarItemIdentifier MPTouchBarItemFormattingIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemStrongIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemEmphasisIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemUnderlineIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemCodeIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemCommentIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemBlockquoteIdentifier;

extern const NSTouchBarItemIdentifier MPTouchBarItemHeadingPopIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH1Identifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH2Identifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH3Identifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH4Identifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH5Identifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH6Identifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemH0Identifier;

extern const NSTouchBarItemIdentifier MPTouchBarItemExternalsIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemLinkIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemImageIdentifier;

extern const NSTouchBarItemIdentifier MPTouchBarItemListsIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemOrderedListIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemSimpleListIdentifier;

extern const NSTouchBarItemIdentifier MPTouchBarItemShiftIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemShiftRightIdentifier;
extern const NSTouchBarItemIdentifier MPTouchBarItemShiftLeftIdentifier;

extern const NSTouchBarItemIdentifier MPTouchBarItemCopyHTMLIdentifier;

@property BOOL scrollsPastEnd;
- (NSRect)contentRect;

@end
