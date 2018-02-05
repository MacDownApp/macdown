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
#import "MPPlugInTouchBarButton.h"

const NSTouchBarItemIdentifier MPTouchBarItemPluginPrefix =
    @"com.uranusjr.macdown.touchbar.plugin.";

@interface MPPlugIn (Tools)

- (NSString *)touchBarIdentifier;
- (MPPlugInTouchBarButton *)makeButton;

@end

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

- (NSDictionary<NSString *, NSTouchBarItem *> *)makeTouchBarItems
{
    NSMutableDictionary<NSString *, NSTouchBarItem *> * items =
        [[NSMutableDictionary alloc] init];

    for (MPPlugIn *plugin in [self buildPlugIns])
    {
        NSString *identifier = [plugin touchBarIdentifier];
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc]
                                      initWithIdentifier:identifier];
        MPPlugInTouchBarButton *button = [plugin makeButton];
        [button setTarget:self];
        [button setTranslatesAutoresizingMaskIntoConstraints:YES];
        [button setPlugin:plugin];

        [item setView:button];
        [item setCustomizationLabel:[plugin name]];

        [items setObject:item forKey:identifier];
    }

    return items;
}

#pragma mark - Private

- (void)invokePlugIn:(id)sender
{
    MPPlugIn *plugin;

    if ([sender isKindOfClass:[NSMenuItem class]])
    {
        plugin = [(NSMenuItem *)sender representedObject];
    }
    else if ([sender isKindOfClass:[MPPlugInTouchBarButton class]])
    {
        plugin = [(MPPlugInTouchBarButton *)sender plugin];
    }

    if (![plugin run:sender])
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


@implementation MPPlugIn (Tools)

- (NSString *)touchBarIdentifier
{
    NSString *sanitizedName = [[self name]
                               stringByReplacingOccurrencesOfString:@" "
                               withString:@"_"];

    return [NSString stringWithFormat:@"%@%@",
            MPTouchBarItemPluginPrefix, sanitizedName];
}

- (MPPlugInTouchBarButton *)makeButton
{
    SEL selector = @selector(invokePlugIn:);

    if (self.touchBarImage)
    {
        return [MPPlugInTouchBarButton buttonWithImage:self.touchBarImage
                                                target:nil
                                                action:selector];
    }
    else
    {
        return [MPPlugInTouchBarButton buttonWithTitle:[self name]
                                                target:nil
                                                action:selector];
    }
}

@end
