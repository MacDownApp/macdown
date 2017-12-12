//
//  NSJSONSerialization+File.m
//  MacDown
//
//  Created by Tzu-ping Chung on 15/3.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import "NSJSONSerialization+File.h"

@implementation NSJSONSerialization (File)

+ (id)JSONObjectWithFileAtURL:(NSURL *)url options:(NSJSONReadingOptions)opt
                        error:(NSError *__autoreleasing *)error
{
    NSInputStream *stream = [NSInputStream inputStreamWithURL:url];
    [stream open];
    id obj = [self JSONObjectWithStream:stream options:opt error:error];
    [stream close];
    return obj;
}

@end
