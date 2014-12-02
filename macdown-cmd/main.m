//
//  main.m
//  macdown-cmd
//
//  Created by Esben Sorig on 30/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <AppKit/AppKit.h>
#import <GBCli/GBCli.h>
#import "NSUserDefaults+Suite.h"
#import "MPGlobals.h"
#import "MPArgumentProcessor.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        MPArgumentProcessor *argproc = [[MPArgumentProcessor alloc] init];

        if (argproc.printsHelp)
            [argproc printHelp:YES];
        else if (argproc.printsVersion)
            [argproc printVersion:YES];

        // Treat all arguments as file names to open. Convert them to absolute
        // paths and store them (as an array) in MacDown's user defaults to
        // be opened later.
        NSString *pwd = [NSFileManager defaultManager].currentDirectoryPath;
        NSURL *pwdUrl = [NSURL fileURLWithPath:pwd isDirectory:YES];
        NSMutableSet *urls = [NSMutableSet set];
        for (NSString *argument in argproc.arguments)
        {
            NSURL *url = [NSURL URLWithString:argument relativeToURL:pwdUrl];
            [urls addObject:url.absoluteString];
        }
        NSUserDefaults *defaults =
            [[NSUserDefaults alloc] initWithSuiteNamed:kMPApplicationSuiteName];
        [defaults setObject:urls.allObjects forKey:@"filesToOpenOnNextLaunch"
               inSuiteNamed:kMPApplicationSuiteName];
        [defaults synchronize];

        // Launch MacDown.
        [[NSWorkspace sharedWorkspace] launchApplication:@"MacDown"];
    }
    return EXIT_SUCCESS;
}

