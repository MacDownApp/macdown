//
//  NSString+LineOffsets.m
//  MacDown
//
//  Created by jj on 03/06/2018.
//  Copyright © 2018 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>

@implementation NSString (LineOffsets)

- (NSArray<NSNumber *> *)lineOffsets
{
    NSMutableArray<NSNumber *> *offsets = [NSMutableArray array];
    __block NSUInteger offset = 0;
    [offsets addObject:@(offset)];    // first line offset.

    [self enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        offset = offset + [line length] + 1;
        [offsets addObject:@(offset)];
    }];
    return offsets;
}

- (NSUInteger)getOffsetOfLineAtLineNumber:(NSUInteger)lineNumber {
    NSUInteger lineIndex = lineNumber - 1;
    __block NSUInteger currentIndex = 0;
    __block NSUInteger offset = 0;
    if (lineIndex > 0) {
        [self enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            if (currentIndex == lineIndex) {
                *stop = YES;
            } else {
                offset = offset + [line length] + 1;
                currentIndex++;
            }
        }];
    }
    return offset;
}

@end
