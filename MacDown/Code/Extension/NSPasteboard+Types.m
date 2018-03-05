//
//  NSPasteboard+Types.m
//  MacDown
//
//  Created by Tzu-ping Chung on 01/3.
//  Copyright © 2016 Tzu-ping Chung . All rights reserved.
//

#import "NSPasteboard+Types.h"


@implementation NSPasteboard (Types)

- (NSURL *)URLForType:(NSString *)dataType
{
    NSString *string = [self stringForType:dataType];

    static NSRegularExpression *schemeRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        schemeRegex = [NSRegularExpression
            regularExpressionWithPattern:@"^(?:https?|file)$"
                                 options:NSRegularExpressionCaseInsensitive
                                   error:NULL];
    });
    

    NSURL *url = [NSURL URLWithString:string];
    if (!url)
        return nil;
    NSString *scheme = url.scheme;
    if (!scheme)
        return nil;
    NSRange matchRange = [schemeRegex
        rangeOfFirstMatchInString:scheme options:0
                          range:NSMakeRange(0, scheme.length)];
    return (matchRange.location != NSNotFound) ? url : nil;
}

@end
