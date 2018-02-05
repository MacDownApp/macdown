//
//  MPPlugInTouchBarButton.h
//  MacDown
//
//  Created by Bruno Philipe on 12/1/17.
//  Copyright © 2017 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MPPlugIn.h"

@interface MPPlugInTouchBarButton : NSButton

@property (strong) MPPlugIn *plugin;

@end
