//
//  NSDocumentController+Document.h
//  MacDown
//
//  Created by Tzu-ping Chung on 25/1.
//  Copyright (c) 2015 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSDocumentController (Document)

- (__kindof NSDocument *)createNewEmptyDocumentForURL:(NSURL *)url
        display:(BOOL)display error:(NSError * __autoreleasing *)error;

// Explicitly note a recently used document URL for the system "Open Recent"
// menu. We filter out temporary files to avoid polluting the list with app
// internals (help/treat files, etc.).
- (void)mp_noteNewRecentDocumentURL:(NSURL *)url;

@end
