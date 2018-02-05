//
//  MPEditorView.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 30/8.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPEditorView.h"
#import "MPMainController.h"
#import "MPUtilities.h"
#import "MPPreferences.h"

const NSTouchBarCustomizationIdentifier MPTouchBarEditorViewIdentifier =
    @"com.uranusjr.macdown.touchbar.editorView";

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

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];

    if (self)
    {
		// The TouchBar for the editor view has to be updated when the value of
		// these preferences changes
		[[MPPreferences sharedInstance] addObserver:self
										 forKeyPath:@"extensionStrikethough"
											options:NSKeyValueObservingOptionOld
											context:nil];

		[[MPPreferences sharedInstance] addObserver:self
										 forKeyPath:@"extensionUnderline"
											options:NSKeyValueObservingOptionOld
											context:nil];

		[[MPPreferences sharedInstance] addObserver:self
										 forKeyPath:@"extensionHighlight"
											options:NSKeyValueObservingOptionOld
											context:nil];
    }

    return self;
}

- (void)dealloc
{
	[[MPPreferences sharedInstance] removeObserver:self
										forKeyPath:@"extensionStrikethough"];
	[[MPPreferences sharedInstance] removeObserver:self
										forKeyPath:@"extensionUnderline"];
	[[MPPreferences sharedInstance] removeObserver:self
										forKeyPath:@"extensionHighlight"];
}

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

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary<NSKeyValueChangeKey,id> *)change
					   context:(void *)context
{
	if (object == [MPPreferences sharedInstance])
	{
		[self setTouchBar:[self makeTouchBar]];
	}
}

#pragma mark - Touch Bar

- (NSTouchBar *)makeTouchBar
{
    id delegate = [[NSApplication sharedApplication] delegate];
    NSTouchBar *touchBar = [[NSTouchBar alloc] init];

    [touchBar setDelegate:self];

    NSMutableArray<NSTouchBarItemIdentifier> *customItems =
        [[NSMutableArray alloc] init];

    [customItems addObjectsFromArray:@[
        MPTouchBarItemHeadingPopIdentifier,
        MPTouchBarItemFormattingIdentifier,
        MPTouchBarItemListsIdentifier,
        MPTouchBarItemBlockquoteIdentifier,
        MPTouchBarItemCodeIdentifier,
        MPTouchBarItemShiftIdentifier,
        MPTouchBarItemCommentIdentifier,
        MPTouchBarItemLinkIdentifier,
        MPTouchBarItemImageIdentifier,
        MPTouchBarItemCopyHTMLIdentifier,
        MPTouchBarItemHideEditorIdentifier,
        MPTouchBarItemHidePreviewIdentifier
    ]];

    // Add items that only should be included if the respective extension
    // is enabled
    if ([delegate respondsToSelector:@selector(extentionTouchBarIdentifiers)])
    {
        [customItems addObjectsFromArray:
            [delegate extentionTouchBarIdentifiers]];
    }

    [customItems addObjectsFromArray:@[
        NSTouchBarItemIdentifierCharacterPicker,
        NSTouchBarItemIdentifierFlexibleSpace,
        NSTouchBarItemIdentifierCandidateList
    ]];

    // Loads the touch bar items for the installed plugins
    if ([delegate respondsToSelector:@selector(pluginEditorTouchBarItems)])
    {
        id items = [delegate pluginEditorTouchBarItems];
        if ([items isKindOfClass:[NSArray<NSTouchBarItemIdentifier> class]])
        {
            [customItems addObjectsFromArray:items];
        }
    }

    [touchBar setDefaultItemIdentifiers:@[
        MPTouchBarItemHeadingPopIdentifier,
        MPTouchBarItemFormattingIdentifier,
        NSTouchBarItemIdentifierFlexibleSpace,
        MPTouchBarItemListsIdentifier,
        MPTouchBarItemLinkIdentifier,
        MPTouchBarItemImageIdentifier,
        NSTouchBarItemIdentifierFlexibleSpace,
        NSTouchBarItemIdentifierCandidateList,
        NSTouchBarItemIdentifierOtherItemsProxy
    ]];

    [touchBar setCustomizationAllowedItemIdentifiers:customItems];

    [touchBar setCustomizationIdentifier:MPTouchBarEditorViewIdentifier];

    return touchBar;
}

#pragma mark - TouchBar Delegate

- (NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar
       makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
    if ([identifier isEqualToString:NSTouchBarItemIdentifierCandidateList])
    {
        // This one we request the default implementation via super
        return [super touchBar:touchBar makeItemForIdentifier:identifier];
    }
    else
    {
        // Otherwise we request that from the App delegate
        // (so the implementation is shared between all views)

        id delegate = [[NSApplication sharedApplication] delegate];

        if ([delegate conformsToProtocol:@protocol(NSTouchBarDelegate)])
        {
            return [delegate touchBar:touchBar
                makeItemForIdentifier:identifier];
        }
    }

    return nil;
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
