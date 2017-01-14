//
//  MPWebView.m
//  MacDown
//
//  Created by Bruno Philipe on 14/1/17.
//  Copyright © 2017 Tzu-ping Chung . All rights reserved.
//

#import "MPWebView.h"
#import "MPUtilities.h"

@implementation MPWebView

- (NSTouchBar *)makeTouchBar
{
    NSTouchBar *touchBar = [[NSTouchBar alloc] init];

    id delegate = [[NSApplication sharedApplication] delegate];

    if ([delegate conformsToProtocol:@protocol(NSTouchBarDelegate)])
    {
        [touchBar setDelegate:delegate];
    }

    [touchBar setDefaultItemIdentifiers:@[
        MPTouchBarItemHideEditorIdentifier,
        MPTouchBarItemHidePreviewIdentifier
    ]];

    return touchBar;
}

@end
