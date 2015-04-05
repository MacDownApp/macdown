//
//  MPOpenQuicklyDataSource.h
//  MacDown
//
//  Created by Orta on 4/5/15.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPOpenQuicklyDataSource : NSObject

- (instancetype)initWithDirectoryPath:(NSString *)directory;
- (void)searchForQuery:(NSString *)query :(void (^)(NSArray *results, NSError *error))completion;

@end
