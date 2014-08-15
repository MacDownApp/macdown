//
//  MPPreferencesViewController.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MPPreferences;


extern NSString * const MPDidRequestEditorSetupNotification;
extern NSString * const MPDidRequestPreviewRenderNotification;

@interface MPPreferencesViewController : NSViewController

- (id)init;

@property (nonatomic, readonly) MPPreferences *preferences;

@end
