//
//  MPEditorView.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 30/8.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPEditorView.h"


@interface MPEditorView ()

@property NSRect contentRect;
@property CGFloat trailingHeight;

@end


@implementation MPEditorView

- (void)setScrollsPastEnd:(BOOL)scrollsPastEnd
{
    _scrollsPastEnd = scrollsPastEnd;
    if (scrollsPastEnd)
        [self updateContentGeometry];
}

- (void)setFrameSize:(NSSize)newSize
{
    if (self.scrollsPastEnd)
    {
        CGFloat ch = self.contentRect.size.height;
        CGFloat eh = self.enclosingScrollView.contentSize.height;
        CGFloat offset = ch < eh ? ch : eh;
        offset -= self.trailingHeight + 2 * self.textContainerInset.height;
        if (offset > 0)
            newSize.height += offset;
    }
    [super setFrameSize:newSize];
}

/** Overriden to perform extra operation on initial text setup.
 *
 * When we first launch the editor, -didChangeText will *not* be called, so we
 * override this to perform required resizing. The -updateContentRect is wrapped
 * inside an NSOperation to be invoked later since the layout manager will not
 * be invoked when the text is first set.
 *
 * @see didChangeText
 * @see updateContentRect
 */
- (void)setString:(NSString *)string
{
    [super setString:string];
    if (self.scrollsPastEnd)
    {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self updateContentGeometry];
        }];
    }
}

/** Overriden to perform extra operation on text change.
 *
 * Updates content height, and invoke the resizing method to apply it.
 *
 * @see updateContentRect
 */
- (void)didChangeText
{
    [super didChangeText];
    if (self.scrollsPastEnd)
        [self updateContentGeometry];
}

- (void)updateContentGeometry
{
    static NSCharacterSet *visibleCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        visibleCharacterSet = ws.invertedSet;
    });

    NSString *content = self.string;
    NSLayoutManager *manager = self.layoutManager;
    NSTextContainer *container = self.textContainer;
    NSRect r = [manager usedRectForTextContainer:container];

    NSRange lastRange = [content rangeOfCharacterFromSet:visibleCharacterSet
                                                 options:NSBackwardsSearch];
    NSRect junkRect = r;
    if (lastRange.location != NSNotFound)
    {
        NSUInteger contentLength = content.length;
        NSUInteger firstJunkLocation = lastRange.location + lastRange.length;
        NSRange junkRange = NSMakeRange(firstJunkLocation,
                                        contentLength - firstJunkLocation);
        junkRect = [manager boundingRectForGlyphRange:junkRange
                                      inTextContainer:container];
    }
    self.trailingHeight = junkRect.size.height;

    NSSize inset = self.textContainerInset;
    r.size.width += 2 * inset.width;
    r.size.height += 2 * inset.height;
    self.contentRect = r;

    [self setFrameSize:self.frame.size];    // Force size update.
}

@end
