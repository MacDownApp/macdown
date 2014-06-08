//
//  MPMarkdownPreferencesViewController.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPMarkdownPreferencesViewController.h"


@implementation MPMarkdownPreferencesViewController

#pragma mark - MASPrefernecesViewController

- (NSString *)identifier
{
    return @"MarkdownPreferences";
}

- (NSImage *)toolbarItemImage
{
    // TODO: Give me an icon.
    return [NSImage imageWithSize:NSMakeSize(1.0, 1.0)
                          flipped:NO
                   drawingHandler:nil];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Markdown", @"Preference pane title.");
}

@end
