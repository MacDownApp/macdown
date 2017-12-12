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

@end
