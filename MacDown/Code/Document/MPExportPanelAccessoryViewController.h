//
//  MPExportPanelAccessoryViewController.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 14/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MPExportPanelAccessoryViewController : NSViewController

@property (getter=isStylesIncluded) BOOL stylesIncluded;
@property (getter=isHighlightingIncluded) BOOL highlightingIncluded;

@end
