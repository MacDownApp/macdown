//
//  MPMainController.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 7/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>
@class MPPreferences;

@interface MPMainController : NSObject <NSApplicationDelegate,
                                        NSTouchBarDelegate>

@property (nonatomic, readonly) MPPreferences *preferences;

#pragma mark - Touch Bar Support

// Extra Touch Bar items available to the editor view. These need to be
// installed by the user from the "View > Customize Touch Bar…" menu.
@property (nonatomic, readonly) NSArray<NSTouchBarItemIdentifier>
    *pluginEditorTouchBarItems;

@property (nonatomic, readonly) NSArray<NSString *>
    *extentionTouchBarIdentifiers;

@end
