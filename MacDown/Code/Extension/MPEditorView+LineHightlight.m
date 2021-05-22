//
//  MPEditorView+LineHightlight.m
//  MacDown
//
//  Created by jj on 03/06/2018.
//  Copyright © 2018 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPEditorView.h"
#import "MPEditorView+LineHightlight.h"

// <http://www.cocoabuilder.com/archive/cocoa/310689-how-to-highlight-the-current-line-in-nstextview.html>
@implementation MPEditorView (LineHighlight)

// FIXME: Should be plugged into the Editor's Preferences Pane.

/**
 * Draws the Editor's view background.
 *
 * Used to highlight the insertion point line.
 *
 * @param rect the rect to draw in.
 */
- (void) drawViewBackgroundInRect:(NSRect)rect
{
    [super drawViewBackgroundInRect:rect];

    NSString *string = [self string];

    if (!string || !self.lineHighlightColor) {
        return;
    }

    NSRange selectedRange = self.selectedRange;
//    NSLog(@"%s: string.length: %tu, selectedRange: [%tu, %tu], \"%@\"",
//          __PRETTY_FUNCTION__,
//          string.length,
//          selectedRange.location,
//          selectedRange.length,
//          [string substringWithRange:selectedRange]
//          );

    if (selectedRange.length > 0) {
        [self setNeedsDisplay:YES];
        return;
    }
    NSLayoutManager *layoutManager = self.layoutManager;
    NSPoint containerOrigin = self.textContainerOrigin;
    NSSize containerInset = self.textContainerInset;
    NSTextContainer * container = self.textContainer;
    NSRect viewBounds = self.bounds;

    CGFloat lineWidth = viewBounds.size.width - 2 * containerInset.width;
    NSRect lineRect = NSZeroRect;

    if ([[string substringWithRange:selectedRange] isEqual: @""]) {
        // This is the case of an empty string or the insertion point at EOL.
        NSRect glyphRect = [layoutManager boundingRectForGlyphRange:selectedRange
                                                   inTextContainer:container];
        lineRect = NSMakeRect(0,
                              glyphRect.origin.y,
                              lineWidth,
                              glyphRect.size.height
                              );
    } else {
        NSRange lineRange = NSMakeRange(0, 0);
        [layoutManager lineFragmentUsedRectForGlyphAtIndex:selectedRange.location
                                            effectiveRange:&lineRange];
        NSRect glyphsRect = [layoutManager
                      boundingRectForGlyphRange:lineRange
                                inTextContainer:[self textContainer]
                                  ];
        lineRect = NSMakeRect(0,
                              glyphsRect.origin.y,
                              lineWidth,
                              glyphsRect.size.height
                              );
    }

    // Convert from view coordinates to container coordinates
    NSRect viewLineRect = NSOffsetRect(lineRect,
                                       containerOrigin.x, containerOrigin.y);
    drawLineHighlight(viewLineRect, self.lineHighlightColor);

}

/**
 * Draw the insertion point line.
 *
 * @param lineRect the rect to draw in.
 * @param lineHighlightColor the color to use.
 */
static void drawLineHighlight(NSRect lineRect, NSColor *lineHighlightColor) {

    if (NSEqualRects(lineRect, NSZeroRect)) {
        return;
    }

    lineRect.size.width = lineRect.size.width - 1;
    [lineHighlightColor set];
    CGFloat lineWidth = 1.0;
    NSRect borderRect = NSInsetRect(lineRect, lineWidth / 2, lineWidth / 2);
    NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:borderRect];
    borderPath.lineWidth = lineWidth;
    [borderPath stroke];
    [borderPath fill];
    [NSGraphicsContext restoreGraphicsState];
}

/**
 * Update the color of the insertion point line highlight.
 *
 * Called when the theme is changed.
 *
 * @Fixme: Should be linked to the theme colors schemes.
 */
- (void) updateLineHighlightColor {
    NSColor *selectionColor = [self.selectedTextAttributes
                               objectForKey:NSBackgroundColorAttributeName];
    NSColor *viewColor = self.backgroundColor;
    self.lineHighlightColor = [viewColor blendedColorWithFraction:0.25
                                                          ofColor:selectionColor];
}

@end
