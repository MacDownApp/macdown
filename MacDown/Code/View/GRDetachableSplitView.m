//
//  GRDetachableSplitView.m
//  Detachable Splitview
//
//  Created by Guilherme Rambo on 01/01/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import "GRDetachableSplitView.h"
#import "MPDocumentPreviewWindow.h"

@interface GRDetachableSplitView () <NSWindowDelegate>

@property (strong) MPDocumentPreviewWindow *detachedPartWindow;
@property (assign) NSRect detachablePartFrameBeforeDetatching;

@end

@implementation GRDetachableSplitView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    if (!(self = [super initWithFrame:frameRect])) return nil;
    
    self.detachablePartIndex = 1;
    
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.detachablePartIndex = 1;
}

- (void)swapViews
{
    self.detachablePartIndex = (self.detachablePartIndex == 1) ? 0 : 1;
    
    NSArray *parts = self.subviews;
    NSView *left = parts[0];
    NSView *right = parts[1];
    
    self.subviews = @[right, left];
}

/** detaches the view at detachablePartIndex **/
- (void)detach
{
    if (self.isDetached) return;
    
    NSView *view = self.subviews[self.detachablePartIndex];
    [view removeFromSuperviewWithoutNeedingDisplay];

    self.detachedPartWindow = [self makeWindowForDetachedView:view];
    [self.detachedPartWindow makeKeyAndOrderFront:nil];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowWillCloseNotification object:self.window queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [self.detachedPartWindow close];
    }];
    
    _detached = YES;
}

/** reattaches the detached view, closeWindow must be YES if the window is not closed yet **/
- (void)reattachClosingWindow:(BOOL)closeWindow
{
    if (!self.isDetached) return;
    
    NSView *view = [self.detachedPartWindow.contentView subviews][0];
    [view removeFromSuperviewWithoutNeedingDisplay];
    view.frame = self.detachablePartFrameBeforeDetatching;
    
    if (self.detachablePartIndex == 1) {
        self.subviews = @[self.subviews[0], view];
    } else {
        self.subviews = @[view, self.subviews[0]];
    }
    
    if (closeWindow) [self.detachedPartWindow close];
    self.detachedPartWindow = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:self.window];
    
    _detached = NO;
}

/** creates and configures the window to contain the newly detached view **/
- (MPDocumentPreviewWindow *)makeWindowForDetachedView:(NSView *)view
{
    NSRect windowRect = [self frameForDetachedWindowToFitView:view];
    NSUInteger windowStyle = NSResizableWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSTitledWindowMask;
    
    MPDocumentPreviewWindow *window = [[MPDocumentPreviewWindow alloc] initWithContentRect:windowRect styleMask:windowStyle backing:NSBackingStoreBuffered defer:NO];
    [window setFirstResponder:self.window.firstResponder];
    window.collectionBehavior |= NSWindowCollectionBehaviorFullScreenPrimary;
    window.delegate = self;
    window.title = [NSString stringWithFormat:NSLocalizedString(@"%@ - Preview", @"[docTitle] - Preview"), self.window.title];
    window.backgroundColor = [NSColor whiteColor];
    [window setReleasedWhenClosed:NO];
    
    if ([window respondsToSelector:@selector(setTitlebarAppearsTransparent:)]) {
        window.titlebarAppearsTransparent = YES;
    }
    
    self.detachablePartFrameBeforeDetatching = view.frame;
    [view setFrameOrigin:NSZeroPoint];
    
    [window.contentView setWantsLayer:YES];
    [window.contentView addSubview:view];
    [window.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[view]-(0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(view)]];
    [window.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[view]-(0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(view)]];
    
    return window;
}

/** returns the frame for the window to fit with the subview to be detached **/
- (NSRect)frameForDetachedWindowToFitView:(NSView *)subview
{
    NSRect convertedRect = [self.window convertRectToScreen:subview.frame];
    CGFloat x = convertedRect.origin.x;
    CGFloat y = convertedRect.origin.y;
    
    return NSMakeRect(x, y, NSWidth(subview.frame), NSHeight(subview.frame));
}

/** NSWindowDelegate call used to reattach the detached view when the detached window is closed **/
- (BOOL)windowShouldClose:(id)sender
{
    [self reattachClosingWindow:NO];
    
    return YES;
}

@end
