//
//  MPMarkdownPreferencesViewController.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPMarkdownPreferencesViewController.h"


@implementation MPMarkdownPreferencesViewController

#pragma mark - MASPreferencesViewController

- (NSString *)viewIdentifier
{
    return @"MarkdownPreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"PreferencesMarkdown"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Markdown", @"Preference pane title.");
}

@end
