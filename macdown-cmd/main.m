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
    @autoreleasepool
    {
        NSString *pwd = [NSFileManager defaultManager].currentDirectoryPath;
        NSURL *pwdUrl = [NSURL fileURLWithPath:pwd isDirectory:YES];
        NSMutableSet *urls = [NSMutableSet set];
        for (int i = 1; i < argc; i++)
        {
            NSString *argument = [NSString stringWithUTF8String:argv[i]];
            NSURL *url = [NSURL URLWithString:argument relativeToURL:pwdUrl];
            [urls addObject:url.absoluteString];
        }
        NSUserDefaults *defaults =
            [[NSUserDefaults alloc] initWithSuiteName:@"com.uranusjr.macdown"];
        [defaults setObject:urls.allObjects forKey:@"filesToOpenOnNextLaunch"];
        [defaults synchronize];

        [[NSWorkspace sharedWorkspace] launchApplication:@"MacDown"];
    }
    return 0;
}

