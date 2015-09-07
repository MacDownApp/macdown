//
//  MPOpenQuicklyDataSource.m
//  MacDown
//
//  Created by Orta on 4/5/15.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import "MPOpenQuicklyDataSource.h"
#import "QSStringRanker.h"

@interface MPOpenQuicklyDataSource()
@property (nonatomic) NSArray *allMarkdownFileURLs;
@end

@implementation MPOpenQuicklyDataSource

- (instancetype)initWithDirectoryPath:(NSString *)directory initialCompletion:(void (^)(NSArray *results))initialCompletion;
{
    NSParameterAssert(initialCompletion);

    self = [super init];
    if (!self) return nil;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self generateResultsForDirectoryPath:directory];
        dispatch_async(dispatch_get_main_queue(), ^{
            initialCompletion(self.allMarkdownFileURLs);
        });
    });

    return self;
}

- (void)generateResultsForDirectoryPath:(NSString *)directoryPath
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *directoryContent = [fm contentsOfDirectoryAtURL:[NSURL fileURLWithPath:directoryPath]
                                  includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                       error:nil];

    NSArray *sortedContent = [directoryContent sortedArrayUsingComparator: ^(NSURL *file1, NSURL *file2) {
      NSDate *file1Date;
      [file1 getResourceValue:&file1Date forKey:NSURLContentModificationDateKey error:nil];

      NSDate *file2Date;
      [file2 getResourceValue:&file2Date forKey:NSURLContentModificationDateKey error:nil];

      return [file1Date compare: file2Date];
    }];

    NSPredicate *mdFltr = [NSPredicate predicateWithFormat:@"self.absoluteString ENDSWITH '.md' OR self.absoluteString ENDSWITH '.markdown'"];
    _allMarkdownFileURLs = [sortedContent filteredArrayUsingPredicate:mdFltr];
}

- (void)searchForQuery:(NSString *)query :(void (^)(NSArray *results))completion;
{
    NSParameterAssert(completion);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSArray *orderedURLs = [self.allMarkdownFileURLs sortedArrayWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(NSURL *obj1, NSURL *obj2) {
            QSDefaultStringRanker *ranker1 = [[QSDefaultStringRanker alloc] initWithString:obj1.lastPathComponent];
            QSDefaultStringRanker *ranker2 = [[QSDefaultStringRanker alloc] initWithString:obj2.lastPathComponent];

            CGFloat value1 = [ranker1 scoreForAbbreviation: query];
            CGFloat value2 = [ranker2 scoreForAbbreviation: query];

            if (value1 == value2) { return NSOrderedSame; }
            if (value1 > value2) { return NSOrderedAscending; }
            return NSOrderedDescending;
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(orderedURLs);
        });
    });
}

@end
