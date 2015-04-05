//
//  MPOpenQuicklyDataSource.m
//  MacDown
//
//  Created by Orta on 4/5/15.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import "MPOpenQuicklyDataSource.h"

@interface MPOpenQuicklyDataSource()
@property (nonatomic) NSArray *allMarkdownFileURLs;
@end

@implementation MPOpenQuicklyDataSource

- (instancetype)initWithDirectoryPath:(NSString *)directory
{
    self = [super init];
    if (!self) return nil;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self generateResultsForDirectoryPath:directory];
    });

    return self;
}

- (void)generateResultsForDirectoryPath:(NSString *)directoryPath
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirContents = [fm contentsOfDirectoryAtPath:directoryPath error:nil];
    NSPredicate *fltr = [NSPredicate predicateWithFormat:@"self ENDSWITH '.md'"];
    _allMarkdownFileURLs = [dirContents filteredArrayUsingPredicate:fltr];
}

- (void)searchForQuery:(NSString *)query :(void (^)(NSArray *results, NSError *error))completion;
{
    NSParameterAssert(completion);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *mutableFileURLs = [NSMutableArray array];
        for (NSString *fileURL in self.allMarkdownFileURLs) {
            NSString *filename = [fileURL lastPathComponent];
            if ( [filename.lowercaseString rangeOfString:query.lowercaseString].location != NSNotFound ) {
                [mutableFileURLs addObject:fileURL];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion([NSArray arrayWithArray:mutableFileURLs], nil);
        });
    });
}



@end
