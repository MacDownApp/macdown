//
//  MPTerminalPreferencesViewController.h
//  MacDown
//
//  Created by Niklas Berglund on 2017-01-11.
//  Copyright © 2017 Tzu-ping Chung . All rights reserved.
//

#import "MPPreferencesViewController.h"
#import <MASPreferences/MASPreferencesViewController.h>

@interface MPTerminalPreferencesViewController : MPPreferencesViewController
    <MASPreferencesViewController>
@property (weak) IBOutlet NSTextField *supportIndicator;
@property (weak) IBOutlet NSTextField *supportText;
@property (weak) IBOutlet NSTextField *location;
@property (weak) IBOutlet NSButton *installUninstallButton;

@end
