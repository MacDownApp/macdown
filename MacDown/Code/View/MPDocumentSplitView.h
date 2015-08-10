//
//  MPDocumentSplitView.h
//  MacDown
//
//  Created by Tzu-ping Chung on 13/12.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GRDetachableSplitView.h"

@interface MPDocumentSplitView : GRDetachableSplitView

@property (assign, nonatomic) CGFloat dividerLocation;

- (void)setDividerColor:(NSColor *)color;

@end
