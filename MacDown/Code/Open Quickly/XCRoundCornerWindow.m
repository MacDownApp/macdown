//
//  XCHeadlessWindow.m
//  XCActionBar
//
//  Created by Pedro Gomes on 11/03/2015.
//  Copyright (c) 2015 Pedro Gomes. All rights reserved.
//

#import "XCRoundCornerWindow.h"

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@implementation XCRoundCornerWindow

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    if((self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag])) {
        self.styleMask                 = NSBorderlessWindowMask;
        self.backgroundColor           = [NSColor clearColor];
        self.opaque                    = NO;
        self.movableByWindowBackground = YES;
        self.hasShadow                 = YES;
    }
    return self;
}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (BOOL)canBecomeKeyWindow
{
    return YES;
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
- (void)setContentView:(NSView *)contentView
{
    contentView.wantsLayer          = YES;
    contentView.layer.frame         = contentView.frame;
    contentView.layer.cornerRadius  = 10.0;
    contentView.layer.masksToBounds = YES;
    
    [super setContentView:contentView];
}

@end
