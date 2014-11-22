//
//  main.m
//  macdown-cmd
//
//  Created by Esben Sorig on 30/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <AppKit/AppKit.h>
#import "version.h"
#import "NSUserDefaults+Suite.h"

static NSString * const kMPMacDownSuiteName = @"com.uranusjr.macdown";

void printHelp()
{
    printf("MacDown %s\n", kMPApplicationVersion);
}

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
            if ([argument isEqualToString:@"-v"]
                || [argument isEqualToString:@"--version"])
            {
                printHelp();
                exit(EXIT_SUCCESS);
            }
            NSURL *url = [NSURL URLWithString:argument relativeToURL:pwdUrl];
            [urls addObject:url.absoluteString];
        }
        NSUserDefaults *defaults =
            [[NSUserDefaults alloc] initWithSuiteNamed:kMPMacDownSuiteName];
        [defaults setObject:urls.allObjects forKey:@"filesToOpenOnNextLaunch"
               inSuiteNamed:kMPMacDownSuiteName];
        [defaults synchronize];

        [[NSWorkspace sharedWorkspace] launchApplication:@"MacDown"];
    }
    return EXIT_SUCCESS;
}

