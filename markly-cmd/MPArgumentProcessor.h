//
//  MPArgumentProcessor.h
//  MacDown
//
//  Created by Tzu-ping Chung on 02/12.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPArgumentProcessor : NSObject

- (instancetype)init;

@property (nonatomic, assign, readonly) BOOL printsHelp;
@property (nonatomic, assign, readonly) BOOL printsVersion;
@property (nonatomic, strong, readonly) NSArray *arguments;

- (void)printHelp:(BOOL)shouldExit;
- (void)printVersion:(BOOL)shouldExit;

@end
