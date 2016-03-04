//
//  NSArray+Map.m
//  MacDown
//
//  Created by Orta Therox on 27/09/2015.
//  Copyright © 2015 Tzu-ping Chung . All rights reserved.
//

#import "NSArray+Map.h"

@implementation NSArray(Map)

- (NSArray *)map:(id (^)(id object))block
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.count];

    for (id object in self) {
        [array addObject:block(object) ?: [NSNull null]];
    }

    return array;
}
@end
