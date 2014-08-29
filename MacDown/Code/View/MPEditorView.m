//
//  MPEditorView.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 30/8.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPEditorView.h"

@implementation MPEditorView

- (void)setFrameSize:(NSSize)newSize
{
    CGFloat pastEnd = self.enclosingScrollView.contentSize.height
                    - self.textContainerInset.height * 2 - self.font.pointSize;
    if (pastEnd > 0.0)
        newSize.height += pastEnd;
    [super setFrameSize:newSize];
}

@end
