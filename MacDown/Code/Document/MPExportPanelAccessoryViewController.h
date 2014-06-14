//
//  MPExportPanelAccessoryViewController.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 14/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, MPAssetsExportOption)
{
    MPAssetsDoNotExport,
    MPAssetsExportExternal,
    MPAssetsExportEmbedded,
};

@interface MPExportPanelAccessoryViewController : NSViewController

@property NSInteger stylesheetOption;
@property NSInteger scriptOption;

@end
