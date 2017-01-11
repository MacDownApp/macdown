//
//  MPEditorView.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 30/8.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPEditorView.h"

const NSTouchBarCustomizationIdentifier MPTouchBarEditorViewIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview";

const NSTouchBarItemIdentifier MPTouchBarItemFormattingIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.formatting";
const NSTouchBarItemIdentifier MPTouchBarItemStrongIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.strong";
const NSTouchBarItemIdentifier MPTouchBarItemEmphasisIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.emphasis";
const NSTouchBarItemIdentifier MPTouchBarItemUnderlineIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.underline";
const NSTouchBarItemIdentifier MPTouchBarItemCodeIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.code";
const NSTouchBarItemIdentifier MPTouchBarItemCommentIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.comment";
const NSTouchBarItemIdentifier MPTouchBarItemBlockquoteIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.blockquote";

const NSTouchBarItemIdentifier MPTouchBarItemHeadingPopIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.headingPopover";
const NSTouchBarItemIdentifier MPTouchBarItemH1Identifier =
	@"com.uranusjr.macdown.touchbar.editorview.h1";
const NSTouchBarItemIdentifier MPTouchBarItemH2Identifier =
	@"com.uranusjr.macdown.touchbar.editorview.h2";
const NSTouchBarItemIdentifier MPTouchBarItemH3Identifier =
	@"com.uranusjr.macdown.touchbar.editorview.h3";
const NSTouchBarItemIdentifier MPTouchBarItemH4Identifier =
	@"com.uranusjr.macdown.touchbar.editorview.h4";
const NSTouchBarItemIdentifier MPTouchBarItemH5Identifier =
	@"com.uranusjr.macdown.touchbar.editorview.h5";
const NSTouchBarItemIdentifier MPTouchBarItemH6Identifier =
	@"com.uranusjr.macdown.touchbar.editorview.h6";
const NSTouchBarItemIdentifier MPTouchBarItemH0Identifier =
	@"com.uranusjr.macdown.touchbar.editorview.h0";

const NSTouchBarItemIdentifier MPTouchBarItemExternalsIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.externals";
const NSTouchBarItemIdentifier MPTouchBarItemLinkIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.link";
const NSTouchBarItemIdentifier MPTouchBarItemImageIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.image";

const NSTouchBarItemIdentifier MPTouchBarItemListsIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.lists";
const NSTouchBarItemIdentifier MPTouchBarItemOrderedListIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.list-ordered";
const NSTouchBarItemIdentifier MPTouchBarItemSimpleListIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.list-simple";

const NSTouchBarItemIdentifier MPTouchBarItemShiftIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.shift";
const NSTouchBarItemIdentifier MPTouchBarItemShiftRightIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.shift-right";
const NSTouchBarItemIdentifier MPTouchBarItemShiftLeftIdentifier =
    @"com.uranusjr.macdown.touchbar.editorview.shift-left";

NS_INLINE BOOL MPAreRectsEqual(NSRect r1, NSRect r2)
{
    return (r1.origin.x == r2.origin.x && r1.origin.y == r2.origin.y
            && r1.size.width == r2.size.width
            && r1.size.height == r2.size.height);
}


@interface MPEditorView ()

@property NSRect contentRect;
@property CGFloat trailingHeight;

@end


@implementation MPEditorView

#pragma mark - Accessors

@synthesize contentRect = _contentRect;
@synthesize scrollsPastEnd = _scrollsPastEnd;

- (BOOL)scrollsPastEnd
{
    @synchronized(self) {
        return _scrollsPastEnd;
    }
}

- (void)setScrollsPastEnd:(BOOL)scrollsPastEnd
{
    @synchronized(self) {
        _scrollsPastEnd = scrollsPastEnd;
        if (scrollsPastEnd)
        {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self updateContentGeometry];
            }];
        }
        else
        {
            // Clears contentRect to fallback to self.frame.
            self.contentRect = NSZeroRect;
        }
    }
}

- (NSRect)contentRect
{
    @synchronized(self) {
        if (MPAreRectsEqual(_contentRect, NSZeroRect))
            return self.frame;
        return _contentRect;
    }
}

- (void)setContentRect:(NSRect)rect
{
    @synchronized(self) {
        _contentRect = rect;
    }
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

#pragma mark - Touch Bar

- (NSTouchBar *)makeTouchBar
{
    NSTouchBar *touchBar = [[NSTouchBar alloc] init];

    [touchBar setDefaultItemIdentifiers:@[
        MPTouchBarItemHeadingPopIdentifier,
        MPTouchBarItemFormattingIdentifier,
        MPTouchBarItemListsIdentifier,
        MPTouchBarItemExternalsIdentifier,
        NSTouchBarItemIdentifierOtherItemsProxy
    ]];

    [touchBar setCustomizationAllowedItemIdentifiers:@[
        MPTouchBarItemHeadingPopIdentifier,
        MPTouchBarItemFormattingIdentifier,
        MPTouchBarItemListsIdentifier,
        MPTouchBarItemBlockquoteIdentifier,
        MPTouchBarItemCodeIdentifier,
        MPTouchBarItemShiftIdentifier,
        MPTouchBarItemCommentIdentifier,
        MPTouchBarItemExternalsIdentifier
    ]];

    [touchBar setCustomizationIdentifier:MPTouchBarEditorViewIdentifier];

    id delegate = [[NSApplication sharedApplication] delegate];

    if ([delegate conformsToProtocol:@protocol(NSTouchBarDelegate)])
    {
        [touchBar setDelegate:delegate];
    }

    return touchBar;
}

#pragma mark - Overrides

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


#pragma mark - Private

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
