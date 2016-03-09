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

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    id q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(q, ^{
        for (MPPlugIn *plugin in [self buildPlugIns])
            [plugin plugInDidInitialize];
    });
    return self;
}


#pragma mark - NSMenuDelegate

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    [menu removeAllItems];
    for (MPPlugIn *plugin in [self buildPlugIns])
    {
        NSMenuItem *item = [menu addItemWithTitle:plugin.name
                                           action:@selector(invokePlugIn:)
                                    keyEquivalent:@""];
        item.target = self;
        item.representedObject = plugin;
    }
}


#pragma mark - Private

- (void)invokePlugIn:(NSMenuItem *)item
{
    MPPlugIn *plugin = item.representedObject;
    if (![plugin run:item])
        NSLog(@"Failed to run plugin %@", plugin.name);
}

- (NSArray<MPPlugIn *> *)buildPlugIns
{
    NSArray *paths = MPListEntriesForDirectory(kMPPlugInsDirectoryName, nil);
    NSMutableArray *plugins = [NSMutableArray arrayWithCapacity:paths.count];
    for (NSString *path in paths)
    {
        if (![path hasExtension:kMPPlugInFileExtension])
            continue;
        NSBundle *bundle = [NSBundle bundleWithPath:path];
        MPPlugIn *plugin = [[MPPlugIn alloc] initWithBundle:bundle];
        if (!plugin)
            continue;
        [plugins addObject:plugin];
    }
    return [plugins copy];
}

@end
