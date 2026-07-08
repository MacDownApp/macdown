//
//  MPEditorView.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 30/8.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//
//  Portions Copyright (c) 2026 Roberto Bissanti.
//

#import "MPEditorView.h"


NS_INLINE BOOL MPAreRectsEqual(NSRect r1, NSRect r2)
{
    return (r1.origin.x == r2.origin.x && r1.origin.y == r2.origin.y
            && r1.size.width == r2.size.width
            && r1.size.height == r2.size.height);
}

NS_INLINE NSDictionary<NSPasteboardReadingOptionKey, id> *MPImageFileReadingOptions(void)
{
    return @{
        NSPasteboardURLReadingFileURLsOnlyKey: @YES,
        NSPasteboardURLReadingContentsConformToTypesKey: @[@"public.image"],
    };
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

- (void)awakeFromNib {
    // NSDragPboard is a *pasteboard name* (identifies which pasteboard),
    // not a drag type/UTI -- registerForDraggedTypes: wants the latter.
    // It happened to work regardless and is now also deprecated; register
    // the actual type this view's -draggingEntered:/-performDragOperation:
    // care about (see MPImageFileReadingOptions() above).
    [self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    [super awakeFromNib];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];

    if ([pboard canReadObjectForClasses:@[[NSURL class]]
                                 options:MPImageFileReadingOptions()]) {
        if (sourceDragMask & NSDragOperationLink) {
            return NSDragOperationLink;
        } else if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }

    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSArray<NSURL *> *fileURLs =
        [pboard readObjectsForClasses:@[[NSURL class]]
                               options:MPImageFileReadingOptions()];
    if (!fileURLs.count)
        return NO;

    // Insert a Markdown reference to each dropped image's path instead of
    // embedding the file's raw bytes as a base64 data URI: the previous
    // implementation read the whole file into memory, base64-encoded it,
    // and inlined it as "![](data:image/jpeg;base64,<...>)" -- unconditionally
    // labeled image/jpeg regardless of the file's real type, and bloating
    // the Markdown source with the full file contents on every drop. A
    // plain path reference is what every other Markdown editor does here,
    // keeps the source text readable, and works for any image type.
    //
    // Plain Markdown ![](), not raw <img>: the full-width preview styling
    // is applied globally in the HTML template (see Default.handlebars)
    // instead of per-image, so the Markdown source stays clean and portable.
    NSMutableString *insertion = [NSMutableString string];
    NSCharacterSet *allowed = [NSCharacterSet URLPathAllowedCharacterSet];
    for (NSURL *fileURL in fileURLs)
    {
        NSString *path = fileURL.path;
        NSString *escapedPath =
            [path stringByAddingPercentEncodingWithAllowedCharacters:allowed];
        [insertion appendFormat:@"![](%@)\n", escapedPath ?: path];
    }

    NSInteger insertionPoint =
        [[[self selectedRanges] objectAtIndex:0] rangeValue].location;
    NSString *text = self.string;
    NSString *newText =
        [NSString stringWithFormat:@"%@%@%@",
            [text substringToIndex:insertionPoint], insertion,
            [text substringFromIndex:insertionPoint]];
    [self setString:newText];
    [self didChangeText];
    return YES;
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
