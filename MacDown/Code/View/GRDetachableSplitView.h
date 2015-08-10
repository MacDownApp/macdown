//
//  GRDetachableSplitView.h
//  Detachable Splitview
//
//  Created by Guilherme Rambo on 01/01/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GRDetachableSplitView : NSSplitView

@property (assign) int detachablePartIndex;
@property (nonatomic, readonly, getter=isDetached) BOOL detached;

- (void)detach;
- (void)reattachClosingWindow:(BOOL)closeWindow;

- (void)swapViews;

@end
