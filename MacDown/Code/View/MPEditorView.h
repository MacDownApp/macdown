//
//  MPEditorView.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 30/8.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MPEditorView : NSTextView <NSTextViewDelegate>

@property BOOL scrollsPastEnd;

/** If set, the insertion point will be placed on that line when file is open.
 *
 * @see openUrlSchemeAppleEvent
 */
@property (nonatomic, strong) NSNumber *insertionPointLine;

/** If set, the insertion point will be placed on that column when file is open.
 *
 * @see openUrlSchemeAppleEvent in MPMainController.
 */
@property (nonatomic, strong) NSNumber *insertionPointColumn;

/**
 * The highlight color of the insertion point line.
 */
// FIXME: Should be linked to the theme colors schemes.
@property (nonatomic, strong) NSColor *lineHighlightColor;

- (NSRect)contentRect;

/**
 * Places the insertion point at given line and column.
 */
- (void)placeInsertionPointAtLine:(NSNumber *)lineNumber column:(NSNumber *)columnNumber;

@end
