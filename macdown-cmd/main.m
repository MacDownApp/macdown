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

static NSString * const kMPApplicationName = @"MacDown";
static NSString * const kMPApplicationSuiteName = @"com.uranusjr.macdown";

NS_INLINE NSStringEncoding MPGetSystemEncoding()
{
    // TODO: Really detect CLI encoding.
    return NSUTF8StringEncoding;
}

NS_INLINE NSString *MPCreateArgument(const char *arg)
{
    return [[NSString alloc] initWithCString:arg
                                    encoding:MPGetSystemEncoding()];
}

NS_INLINE void printHelp()
{
    const char *appName =
        [kMPApplicationName cStringUsingEncoding:MPGetSystemEncoding()];
    printf("%s %s (%s)\n",
           appName, kMPApplicationShortVersion, kMPApplicationBundleVersion);
}

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        // If the first argument is -v or --version, print the version and exit.
        if (argc > 1)
        {
            NSString *f = MPCreateArgument(argv[1]);
            if ([f isEqualToString:@"-v"] || [f isEqualToString:@"--version"])
            {
                printHelp();
                exit(EXIT_SUCCESS);
            }
        }

        // Treat all arguments as file names to open. Convert them to absolute
        // paths and store them (as an array) in MacDown's user defaults to
        // be opened later.
        NSString *pwd = [NSFileManager defaultManager].currentDirectoryPath;
        NSURL *pwdUrl = [NSURL fileURLWithPath:pwd isDirectory:YES];
        NSMutableSet *urls = [NSMutableSet set];
        for (int i = 1; i < argc; i++)
        {
            NSString *argument = MPCreateArgument(argv[i]);
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

