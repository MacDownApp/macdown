//
//  NSTouchBarItem+QuickConstructor.h
//  MacDown
//
//  Created by Bruno Philipe on 9/1/17.
//  Copyright © 2017 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSTouchBarItem (QuickConstructor)

+ (NSCustomTouchBarItem *)customWith:(NSTouchBarItemIdentifier)identifier;

@end
