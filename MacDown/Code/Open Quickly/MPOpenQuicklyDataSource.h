//
//  MPOpenQuicklyDataSource.h
//  MacDown
//
//  Created by Orta on 4/5/15.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPOpenQuicklyDataSource : NSObject

/// In the background will get all the markdown files in the same directory
/// as the directory, then send the completion block when finished.
- (instancetype)initWithDirectoryPath:(NSString *)directory initialCompletion:(void (^)(NSArray *results))initialCompletion;

/// Uses Quicksilver's string completion on all the known markdown files in
/// the search cache.

- (void)searchForQuery:(NSString *)query :(void (^)(NSArray *results))completion;

@end
