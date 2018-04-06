//
//  NSPasteboard+Types.h
//  MacDown
//
//  Created by Tzu-ping Chung on 01/3.
//  Copyright © 2016 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSPasteboard (Types)

- (NSURL *)URLForType:(NSString *)dataType;

@end
