//
//  NSUserDefaults+Suite.h
//  MacDown
//
//  Created by Tzu-ping Chung on 19/11.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSUserDefaults (Suite)

- (instancetype)initWithSuiteNamed:(NSString *)suiteName;
- (id)objectForKey:(NSString *)key inSuiteNamed:(NSString *)suiteName;
- (void)setObject:(id)value forKey:(NSString *)key
     inSuiteNamed:(NSString *)suiteName;

@end
