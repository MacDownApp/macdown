//
//  MPExportPanelAccessoryViewController.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 14/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPExportPanelAccessoryViewController.h"

@interface MPExportPanelAccessoryViewController ()

@property (weak) IBOutlet NSPopUpButton *stylesheetOptionSelect;
@property (weak) IBOutlet NSPopUpButton *scriptOptionSelect;

@end


@implementation MPExportPanelAccessoryViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self)
        return self;
    return self;
}

- (NSString *)nibName
{
    return NSStringFromClass(self.class);
}

@end
