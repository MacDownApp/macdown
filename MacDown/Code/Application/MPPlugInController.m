//
//  MPPlugInController.m
//  MacDown
//
//  Created by Tzu-ping Chung on 02/3.
//  Copyright © 2016 Tzu-ping Chung . All rights reserved.
//

#import "NSString+Lookup.h"
#import "MPPlugIn.h"
#import "MPPlugInController.h"
#import "MPUtilities.h"


@implementation MPPlugInController

#pragma mark - NSMenuDelegate

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    NSArray *paths = MPListEntriesForDirectory(
        kMPPlugInsDirectoryName, nil);

    [menu removeAllItems];
    for (NSString *path in paths)
    {
        if (![path hasExtension:kMPPlugInFileExtension])
            continue;
        NSBundle *bundle = [NSBundle bundleWithPath:path];
        MPPlugIn *plugin = [[MPPlugIn alloc] initWithBundle:bundle];
        if (!plugin)
            continue;
        NSMenuItem *item = [menu addItemWithTitle:plugin.name
                                           action:@selector(invokePlugIn:)
                                    keyEquivalent:@""];
        item.target = self;
        item.representedObject = plugin;
    }
}

- (IBAction)invokePlugIn:(NSMenuItem *)item
{
    MPPlugIn *plugin = item.representedObject;
    if (![plugin run:item])
        NSLog(@"Failed to run plugin %@", plugin.name);
}

@end
