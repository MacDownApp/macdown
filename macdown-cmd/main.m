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


NSRunningApplication *MPRunningMacDownInstance()
{
    NSArray *runningInstances = [NSRunningApplication
        runningApplicationsWithBundleIdentifier:kMPApplicationSuiteName];
    return runningInstances.firstObject;
}


void MPCollectForRunningMacDown(NSOrderedSet *urls)
{
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    for (NSString *url in urls)
    {
        NSString *path = [NSURL URLWithString:url].path;
        [workspace openFile:path withApplication:kMPApplicationName];
    }
}


void MPCollectForUnlaunchedMacDown(NSOrderedSet *urls)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteNamed:kMPApplicationSuiteName];
    [defaults setObject:urls.array forKey:@"filesToOpenOnNextLaunch"
           inSuiteNamed:kMPApplicationSuiteName];
    [defaults synchronize];
}


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
        NSMutableOrderedSet *urls = [NSMutableOrderedSet orderedSet];
        for (NSString *argument in argproc.arguments)
        {
            NSURL *url = [NSURL URLWithString:argument relativeToURL:pwdUrl];
            [urls addObject:url.absoluteString];
        }

        // If the application is running, open all files with the first running
        // instance. Otherwise save the file URLs, and start the app (saved URLs
        // will be opened when the app launches).
        NSRunningApplication *instance = MPRunningMacDownInstance();
        if (instance)
            MPCollectForRunningMacDown(urls);
        else
            MPCollectForUnlaunchedMacDown(urls);

        // Launch MacDown.
        [[NSWorkspace sharedWorkspace] launchApplication:@"MacDown"];
    }
    return EXIT_SUCCESS;
}

