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


const NSUInteger kMPPathEncoding = NSUTF8StringEncoding;


NSRunningApplication *MPRunningMacDownInstance()
{
    NSArray *runningInstances = [NSRunningApplication
        runningApplicationsWithBundleIdentifier:kMPApplicationSuiteName];
    return runningInstances.firstObject;
}

void MPCollectForMacDown(NSOrderedSet<NSURL *> *urls)
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteNamed:kMPApplicationSuiteName];
    NSMutableArray<NSString *> *urlStrings =
        [[NSMutableArray alloc] initWithCapacity:urls.count];
    for (NSURL *url in urls)
        [urlStrings addObject:url.path];
    [defaults setObject:urlStrings forKey:kMPFilesToOpenKey
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
        NSMutableOrderedSet<NSURL *> *urls = [NSMutableOrderedSet orderedSet];
        for (NSString *arg in argproc.arguments)
        {
            NSString *escaped =
                [arg stringByAddingPercentEscapesUsingEncoding:kMPPathEncoding];
            NSURL *url = [NSURL URLWithString:escaped relativeToURL:pwdUrl];
            [urls addObject:url];
        }
        MPCollectForMacDown(urls);

        // Launch MacDown.
        [[NSWorkspace sharedWorkspace] launchApplication:kMPApplicationName];
    }
    return EXIT_SUCCESS;
}

