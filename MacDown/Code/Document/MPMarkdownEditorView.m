//
//  MPMarkdownEditorView.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 15/7.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPMarkdownEditorView.h"

@implementation MPMarkdownEditorView

- (void)setFrameSize:(NSSize)newSize
{
    if (newSize.height > self.enclosingScrollView.frame.size.height)
        newSize.height += 35.0;
    [super setFrameSize:newSize];
}

@end
