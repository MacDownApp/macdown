//
//  main.m
//  MacDown-cmd
//
//  Created by Esben Sorig on 30/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <AppKit/AppKit.h>

int main(int argc, const char * argv[])
{
    if (argc > 1) {
        [[NSWorkspace sharedWorkspace] openFile:[NSString stringWithUTF8String:argv[1]]
                                withApplication:@"MacDown"];
    }
    else {
        [[NSWorkspace sharedWorkspace] launchApplication:@"MacDown"];
    }

    return 0;
}

