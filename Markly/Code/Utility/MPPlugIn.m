//
//  MPPlugIn.m
//  MacDown
//
//  Created by Tzu-ping Chung on 02/3.
//  Copyright © 2016 Tzu-ping Chung . All rights reserved.
//

#import "MPPlugIn.h"


@interface MPPlugIn ()
@property (nonatomic) id content;
@end


@implementation MPPlugIn

- (void)setName:(NSString *)name
{
    _name = name;
}

- (instancetype)initWithBundle:(NSBundle *)bundle
{
    self = [super init];
    if (!self)
        return nil;

    if (!bundle.isLoaded)
    {
        NSError *e = nil;
        BOOL ok = [bundle loadAndReturnError:&e];
        if (!ok)
            return nil;
    }
    Class plugInClass = bundle.principalClass;
    if (!plugInClass)
        return nil;
    self.content = [[plugInClass alloc] init];

    if ([self.content respondsToSelector:@selector(name)])
        self.name = [self.content name];
    if (!self.name)
    {
        NSURL *url = bundle.bundleURL;
        self.name = url.lastPathComponent.stringByDeletingPathExtension;
    }

    return self;
}

- (void)plugInDidInitialize
{
    if ([self.content respondsToSelector:@selector(plugInDidInitialize)])
        [self.content plugInDidInitialize];
}

- (BOOL)run:(id)sender
{
    if ([self.content respondsToSelector:@selector(run:)])
        return [self.content run:sender];
    return NO;
}

@end
