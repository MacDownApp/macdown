//
//  MPDocumentPreviewWindow.m
//  MacDown
//
//  Created by Guilherme Rambo on 01/01/15.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import "MPDocumentPreviewWindow.h"

@implementation MPDocumentPreviewWindow
{
    NSResponder *_fakedFirstResponder;
}

- (void)setFirstResponder:(NSResponder *)firstResponder
{
    [self willChangeValueForKey:@"firstResponder"];
    _fakedFirstResponder = firstResponder;
    [self didChangeValueForKey:@"firstResponder"];
}

- (NSResponder *)firstResponder
{
    return _fakedFirstResponder;
}

@end
