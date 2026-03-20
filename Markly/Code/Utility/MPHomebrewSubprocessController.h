//
//  MPHomebrewSubprocessController.h
//  MacDown
//
//  Created by Tzu-ping Chung on 18/2.
//  Copyright © 2017 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MPHomebrewSubprocessController : NSObject

- (instancetype)initWithArguments:(NSArray *)args;
- (void)runWithCompletionHandler:(void(^)(NSString *))handler;

@end


void MPDetectHomebrewPrefixWithCompletionhandler(void(^handler)(NSString *));
