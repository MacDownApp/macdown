//
//  MPDocumentPreviewWindow.h
//  MacDown
//
//  Created by Guilherme Rambo on 01/01/15.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>

/**
 A NSWindow subclass with a settable firstResponder
 */
@interface MPDocumentPreviewWindow : NSWindow

- (void)setFirstResponder:(NSResponder *)firstResponder;

@end
