//
//  MPPlugIn.h
//  MacDown
//
//  Created by Tzu-ping Chung on 02/3.
//  Copyright © 2016 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPDOcument.h"

@interface MPPlugIn : NSObject

@property (nonatomic, readonly) NSString *name;

- (instancetype)initWithBundle:(NSBundle *)bundle;
- (BOOL)run:(id)sender;

- (void)plugInDidInitialize;

@end
