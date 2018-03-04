//
//  MPMathJaxCallbackHandler.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 07/8.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPMathJaxListener : NSObject

- (void)addCallback:(void (^)(void))block forKey:(NSString *)key;
- (void)invokeCallbackForKey:(NSString *)key;

@end
