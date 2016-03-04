//
// QSStringRanker.m
// Quicksilver
//
// Created by Alcor on 1/28/05.
// Copyright 2005 Blacktree. All rights reserved.
//

#import "QSStringRanker.h"
#import "QSense.h"
#import "NSString_Purification.h"

@implementation QSDefaultStringRanker
- (id)initWithString:(NSString *)string {
	if (!string) {
		return nil;
    }
    self = [super init];
    if (self) {
        [self setRankedString:string];
    }
	return self;
}

- (void)dealloc {
	normString = nil;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@ %@", [super description], normString];
}

- (NSString*)rankedString { return normString; }
- (void)setRankedString:(NSString*)aString {
    if (aString != normString) {
        normString = [aString purifiedString];
    }
}

- (CGFloat)scoreForAbbreviation:(NSString*)anAbbreviation {
	return QSScoreForAbbreviation((__bridge CFStringRef) normString, (__bridge CFStringRef)anAbbreviation, nil);
}

- (NSIndexSet*)maskForAbbreviation:(NSString*)anAbbreviation {
	NSMutableIndexSet *mask = [NSMutableIndexSet indexSet];
	QSScoreForAbbreviation((__bridge CFStringRef) normString, (__bridge CFStringRef)anAbbreviation, mask);
	return mask;
}
@end
