//
//  MPDocument.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 6/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MPPreferences;


@interface MPDocument : NSDocument {
    NSString *htmlString;
}

@property (nonatomic, readonly) MPPreferences *preferences;

@end
