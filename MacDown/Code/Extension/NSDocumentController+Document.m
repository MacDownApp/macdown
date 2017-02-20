//
//  NSDocumentController+Document.m
//  MacDown
//
//  Created by Tzu-ping Chung on 25/1.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import "NSDocumentController+Document.h"

@implementation NSDocumentController (Document)

- (__kindof NSDocument *)createNewEmptyDocumentForURL:(NSURL *)url
        display:(BOOL)display error:(NSError * __autoreleasing *)error
{
    [[NSFileManager defaultManager] createFileAtPath:[url path]
                                            contents:[NSData data]
                                          attributes:nil];

    NSDocument *doc = [self openUntitledDocumentAndDisplay:display
                                                     error:error];
    if (!doc)
        return doc;

    doc.draft = YES;
    doc.fileURL = url;
    return doc;
}

@end
