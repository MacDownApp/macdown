//
//  NSArray+Map.h
//  MacDown
//
//  Created by Orta Therox on 27/09/2015.
//  Copyright © 2015 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSArray(Map)
- (NSArray *)map:(id (^)(id object))block;
@end
