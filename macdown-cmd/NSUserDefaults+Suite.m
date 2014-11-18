//
//  NSUserDefaults+Suite.m
//  MacDown
//
//  Created by Tzu-ping Chung on 19/11.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "NSUserDefaults+Suite.h"

@implementation NSUserDefaults (Suite)

- (instancetype)initWithSuiteNamed:(NSString *)suiteName
{
    self = [self init];
    if (!self)
        return nil;
    [self addSuiteNamed:suiteName];
    return self;
}

- (void)setObject:(id)value forKey:(NSString *)key
     inSuiteNamed:(NSString *)suiteName
{
    CFPreferencesSetValue((__bridge CFStringRef)key,
                          (__bridge CFPropertyListRef)value,
                          (__bridge CFStringRef)suiteName,
                          kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}

@end
