//
//  MPOpenQuicklyDataSource.m
//  MacDown
//
//  Created by Orta Therox on 27/09/2015.
//  Copyright © 2015 Tzu-ping Chung . All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MPOpenQuicklyDataSource.h"

@interface MPOpenQuicklyDataSource()
// Let's us make synchronous searches instead of using the async searchForQuery::
- (NSArray *)orderedURLsWithQuery:(NSString *)query;

// The underlying array of NSURLs
@property (nonatomic) NSArray *allMarkdownFileURLs;
@end

@interface MPOpenQuicklyDataSourceTests : XCTestCase
@end

@implementation MPOpenQuicklyDataSourceTests

- (void)testGetsRightIndexes
{
    MPOpenQuicklyDataSource *dataSource = [[MPOpenQuicklyDataSource alloc] init];
    NSURL *fileURL = [NSURL URLWithString:@"hello-world.md"];
    NSIndexSet *indexes = [dataSource queryResultsIndexesOnQuery:@"hw" fileURL:fileURL];
    XCTAssertTrue([indexes containsIndex:0]);
    XCTAssertTrue([indexes containsIndex:6]);
}


- (void)testRemovesJekyllPrefixes
{
    MPOpenQuicklyDataSource *dataSource = [[MPOpenQuicklyDataSource alloc] init];
    NSURL *fileURL = [NSURL URLWithString:@"2011-01-05-hello.md"];
    NSIndexSet *indexes = [dataSource queryResultsIndexesOnQuery:@"h" fileURL:fileURL];
    XCTAssertTrue([indexes containsIndex:11]);
}


@end
