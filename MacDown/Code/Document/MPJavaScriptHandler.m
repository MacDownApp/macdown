//
//  MPJavaScriptHandler.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 30/6.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPJavaScriptHandler.h"

@implementation MPJavaScriptHandler

- (void)checkboxWithId:(NSUInteger)boxId didChangeValue:(BOOL)checked
{
    [self.delegate checkboxWithId:boxId didChangeValue:checked];
}


#pragma mark - WebScriptObject

+ (NSString *)webScriptNameForSelector:(SEL)selector
{
    if (selector == @selector(checkboxWithId:didChangeValue:))
        return @"checkboxDidChangeValue";
    return nil;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector
{
    if (selector == @selector(checkboxWithId:didChangeValue:))
        return NO;
    return YES;
}

@end
