//
//  NSDocumentController+Document.m
//  MacDown
//
//  Created by Tzu-ping Chung on 25/1.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import "NSDocumentController+Document.h"

@implementation NSDocumentController (Document)

- (id)openUntitledDocumentForURL:(NSURL *)url display:(BOOL)display
                           error:(NSError * __autoreleasing *)error
{
    NSDocument *doc = [self openUntitledDocumentAndDisplay:display error:error];
    if (!doc)
        return doc;

    doc.draft = YES;
    doc.fileURL = url;
    return doc;
}

@end
