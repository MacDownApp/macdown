//
//  MPMathJaxCallbackHandler.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 07/8.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPMathJaxListener.h"

@interface MPMathJaxListener ()
@property (nonatomic) NSMutableDictionary *callbacks;
@end

@implementation MPMathJaxListener

- (NSMutableDictionary *)callbacks
{
    if (!_callbacks)
        _callbacks = [[NSMutableDictionary alloc] init];
    return _callbacks;
}

- (void)addCallback:(void (^)(void))block forKey:(NSString *)key
{
    self.callbacks[key] = block;
}

- (void)invokeCallbackForKey:(NSString *)key
{
    id object = self.callbacks[key];
    if (object)
    {
        void (^block)(void) = object;
        block();
    }
}


#pragma mark - WebScripting

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector
{
    if (selector == @selector(invokeCallbackForKey:))
        return NO;
    return YES;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name
{
    if (strncmp(name, "_callbacks", 10) == 0)
        return NO;
    return YES;
}

@end
