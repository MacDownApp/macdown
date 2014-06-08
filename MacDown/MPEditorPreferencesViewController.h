//
//  MPEditorPreferencesViewController.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPPreferencesViewController.h"
#import <MASPreferences/MASPreferencesViewController.h>

@interface MPEditorPreferencesViewController : MPPreferencesViewController
    <MASPreferencesViewController>

@property (readonly) NSInteger xInsetTick;
@property (readonly) NSInteger yInsetTick;

@end
