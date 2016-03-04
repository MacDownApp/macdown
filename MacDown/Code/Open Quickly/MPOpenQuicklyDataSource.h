//
//  MPOpenQuicklyDataSource.h
//  MacDown
//
//  Created by Orta on 4/5/15.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPOpenQuicklyEntry : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSURL *url;
@property (nonatomic, assign) CGFloat scoreForQuery;
@property (nonatomic, copy) NSIndexSet *indexesOfResults;
@end


@interface MPOpenQuicklyDataSource : NSObject

/// In the background will get all the markdown files in the same directory
/// as the directory, then send the completion block when finished with an array of MPOpenQuicklyEntry.
- (instancetype)initWithDirectoryPath:(NSString *)directory initialCompletion:(void (^)(NSArray *results))initialCompletion;

/// Uses Quicksilver's string completion on all the known markdown files in
/// the search cache. Returns an array of MPOpenQuicklyEntry.

- (void)searchForQuery:(NSString *)query :(void (^)(NSArray *results))completion;

@end
