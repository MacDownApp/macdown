//
//  MPPreferencesViewController.h
//  MarkPad
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MPPreferences;


@interface MPPreferencesViewController : NSViewController

- (id)init;

@property (nonatomic, weak, readonly) MPPreferences *preferences;

@end
