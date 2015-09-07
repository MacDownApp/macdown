//
// NSString_Purification.m
// Quicksilver
//
// Created by Alcor on Fri May 14 2004.
// Copyright (c) 2004 Blacktree. All rights reserved.
//

#import "NSString_Purification.h"

@implementation NSString (Purification)
- (NSString *)purifiedString {
	NSMutableString *string = [[self precomposedStringWithCanonicalMapping] mutableCopy];
	NSRange range;
	NSCharacterSet *set = [NSCharacterSet nonBaseCharacterSet];
	range = NSMakeRange([string length], 0);
	while((range = [string rangeOfCharacterFromSet:set options:NSBackwardsSearch range:NSMakeRange(0, range.location)]).location != NSNotFound) {
		[string deleteCharactersInRange:range];
	}
    
    if ([self isEqualToString:string]) {
        return self;
    }
    else {
        return string;
    }
}
@end
