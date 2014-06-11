//
//  NSString+Lookup.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 11/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "NSString+Lookup.h"
#import "MPUtilities.h"


@implementation NSString (Lookup)

- (NSInteger)locationOfFirstNewlineBefore:(NSUInteger)location
{
    NSUInteger length = self.length;
    if (location > length)
        location = length;
    NSInteger p = location - 1;
    while (p >= 0 && !MPCharacterIsNewline([self characterAtIndex:p]))
        p--;
    return p;
}

- (NSUInteger)locationOfFirstNewlineAfter:(NSUInteger)location
{
    NSUInteger length = self.length;
    if (location >= length)
        return length;
    NSInteger p = location + 1;
    while (p < length && !MPCharacterIsNewline([self characterAtIndex:p]))
        p++;
    return p;
}

- (NSUInteger)locationOfFirstNonWhitespaceCharacterInLineBefore:(NSUInteger)loc
{
    NSInteger p = [self locationOfFirstNewlineBefore:loc] + 1;
    NSUInteger length = self.length;
    if (loc > length)
        loc = length;
    while (p < loc && MPCharacterIsWhitespace([self characterAtIndex:p]))
        p++;
    return p;
}

@end