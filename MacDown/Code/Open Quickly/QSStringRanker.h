//
//  QSStringRanker.h
//  Quicksilver
//
//  Created by Alcor on 1/28/05.
//  Copyright 2005 Blacktree. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol QSStringRanker
- (id)initWithString:(NSString *)string;
- (CGFloat)scoreForAbbreviation:(NSString*)anAbbreviation;
- (NSIndexSet*)maskForAbbreviation:(NSString*)anAbbreviation;
- (NSString*)rankedString;
- (void)setRankedString:(NSString*)aString;
@end

@interface QSDefaultStringRanker : NSObject <QSStringRanker> {
	NSString *normString;
}

@end
