//
//  MPEditorView.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 30/8.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPEditorView.h"

// If an image dragged into the editor pane generates a Base64
// string over this length, warn the user that linking
// may be a better option.
static NSUInteger kLargBase64WarnThreshold = 256;

typedef NS_ENUM(NSUInteger, MPEmbedPreference)
{
  MPStringEmbedPreference = 0,
  MPLinkEmbedPreference = 1,
};

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

- (void)awakeFromNib {
    [self registerForDraggedTypes:[NSArray arrayWithObjects: NSDragPboard, nil]];
    [super awakeFromNib];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
    
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
    
    if ([pboard canReadItemWithDataConformingToTypes:[NSArray arrayWithObjects:@"public.jpeg", nil]]) {
        if (sourceDragMask & NSDragOperationLink) {
            return NSDragOperationLink;
        } else if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }
    
    return NSDragOperationNone;
}

#define PERFORM_DRAG_BASE64_INFORMATIVE NSLocalizedString( \
@"Embedding the image will add %d characters to the document \
text. Alternately, MacDown can generate a link to the image.", \
@"large base64 string information")

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
    
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
    
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        
        /* Load data of file. */
        NSError *error;
        NSData *fileData = [NSData dataWithContentsOfFile: files[0]
                                                  options: NSMappedRead
                                                    error: &error];
        if (!error)
        {
            // convert to base64 representation
            NSString *dataString = [fileData base64Encoding];
            
            // if the string is sufficiently large, prompt the user
            MPEmbedPreference embedStyle = MPStringEmbedPreference;
            if ( [dataString length] > kLargBase64WarnThreshold )
            {
                embedStyle = [self warnForLargeEmbed:dataString];
            }

            // generate a relative link or an embedded base64
            NSString *embeddedString;
            if ( MPStringEmbedPreference == embedStyle )
            {
                embeddedString = [NSString stringWithFormat:@"![](data:image/jpeg;base64,%@)",
                                            dataString];
            }
            else if ( MPLinkEmbedPreference == embedStyle )
            {
                embeddedString = [NSString stringWithFormat:@"![](%@)", files[0]];
            }
            else
            {
                // Cancel button pressed/error
                return NO;
            }
                
            // insertText is used over setting the backing textStorage
            // directly, as insertText will trigger the undo manager
            [self insertText:embeddedString];
        } else {
            return NO;
        }
    }
    return YES;
}

- (MPEmbedPreference)warnForLargeEmbed:(NSString *)dataString
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Embedding this image will result in a large document.",
                                              @"large base64 string warning");
    alert.informativeText = [NSString stringWithFormat:PERFORM_DRAG_BASE64_INFORMATIVE,
                             [dataString length]];
    [alert addButtonWithTitle:NSLocalizedString(@"Generate Link",
                                                @"large base64 string link button")];
    [alert addButtonWithTitle:NSLocalizedString(@"Embed Anyways",
                                                @"large base64 string embed button")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel",
                                                @"large base64 string cancel button")];
    
    NSModalResponse response = [alert runModal];
    MPEmbedPreference result = -1;
    switch (response)
    {
        case NSAlertFirstButtonReturn:
            result = MPLinkEmbedPreference;
            break;
        
        case NSAlertSecondButtonReturn:
            result = MPStringEmbedPreference;
            break;
        
        default:
            result = -1;
            break;
    }
    return result;
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
