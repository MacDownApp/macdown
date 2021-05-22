//
//  NSString+LineOffsets.h
//  MacDown
//
//  Created by jj on 03/06/2018.
//  Copyright © 2018 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (LineOffsets)

- (NSArray *)lineOffsets;
- (NSUInteger)getOffsetOfLineAtLineNumber:(NSUInteger)index;

@end
