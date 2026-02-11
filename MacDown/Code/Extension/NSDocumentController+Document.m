//
//  NSDocumentController+Document.m
//  MacDown
//
//  Created by Tzu-ping Chung on 25/1.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import "NSDocumentController+Document.h"

@implementation NSDocumentController (Document)

- (void)mp_noteNewRecentDocumentURL:(NSURL *)url
{
    if (!url || !url.isFileURL)
        return;

    NSString *path = url.path;
    if (!path.length)
        return;

    // Skip temp files (help, treats, other internal/generated docs).
    NSString *tmp = NSTemporaryDirectory();
    if (tmp.length)
    {
        NSString *tmpResolved =
            [[tmp stringByStandardizingPath] stringByResolvingSymlinksInPath];
        if (tmpResolved.length && ![tmpResolved hasSuffix:@"/"])
            tmpResolved = [tmpResolved stringByAppendingString:@"/"];

        NSString *pathResolved =
            [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];
        if (tmpResolved.length && [pathResolved hasPrefix:tmpResolved])
            return;
    }

    // Recent-documents updates are UI-adjacent; keep it on the main queue.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self noteNewRecentDocumentURL:url];
    });
}

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
    [self mp_noteNewRecentDocumentURL:url];
    return doc;
}

@end
