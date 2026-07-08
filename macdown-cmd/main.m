//
//  main.m
//  macdown-cmd
//
//  Created by Esben Sorig on 30/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//
//  Portions Copyright (c) 2026 Roberto Bissanti.
//

#import <sys/time.h>
#import <AppKit/AppKit.h>
#import <GBCli/GBCli.h>
#import "NSUserDefaults+Suite.h"
#import "MPGlobals.h"
#import "MPArgumentProcessor.h"


NSRunningApplication *MPRunningMacDownInstance(void)
{
    NSArray *runningInstances = [NSRunningApplication
        runningApplicationsWithBundleIdentifier:kMPApplicationSuiteName];
    return runningInstances.firstObject;
}

void MPCollectPipedContentURLForMacDown(NSURL *url) {
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteNamed:kMPApplicationSuiteName];
    
    [defaults setObject:url.path forKey:kMPPipedContentFileToOpen inSuiteNamed:kMPApplicationSuiteName];
    [defaults synchronize];
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

/**
 * Data piped to macdown through stdin.
 * 
 * @return Piped data if any, otherwise nil.
 */
NSData* MPPipedData(void) {
    NSFileHandle *stdInFileHandle = [NSFileHandle fileHandleWithStandardInput];
    // Check if stdin file handle have anything to read
    // Modified solution from http://stackoverflow.com/questions/7505777/how-do-i-check-for-nsfilehandle-has-data-available
    int fd = [stdInFileHandle fileDescriptor];
    fd_set fdset;
    struct timeval tmout = { 0, 0 };
    FD_ZERO(&fdset);
    FD_SET(fd, &fdset);
    if (select(fd + 1, &fdset, NULL, NULL, &tmout) <= 0) { // Doesn't hold any data
        return nil;
    }
    else if (FD_ISSET(fd, &fdset)) { // Holds data
        NSData *stdInData = [NSData dataWithData:[stdInFileHandle readDataToEndOfFile]];
        return stdInData;
    }
    else {
        return nil;
    }
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
        
        NSData *dataFromPipe = MPPipedData();
        
        if (dataFromPipe) {
            // Store piped content in a temporary file which will be read by MacDown on launch
            NSString *fileName = [NSString stringWithFormat:@"%@_%@", [[NSProcessInfo processInfo] globallyUniqueString], @"pipedText.txt"];
            NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
            
            NSError *writeError;
            [dataFromPipe writeToFile:fileURL.path options:0 error:&writeError];
            
            if (writeError == nil) {
                MPCollectPipedContentURLForMacDown(fileURL);
            }
        }

        // Treat all arguments as file names to open. Convert them to absolute
        // paths and store them (as an array) in MacDown's user defaults to
        // be opened later.
        NSString *pwd = [NSFileManager defaultManager].currentDirectoryPath;
        NSURL *pwdUrl = [NSURL fileURLWithPath:pwd isDirectory:YES];
        NSMutableOrderedSet<NSURL *> *urls = [NSMutableOrderedSet orderedSet];
        for (NSString *arg in argproc.arguments)
        {
            // stringByAddingPercentEscapesUsingEncoding: is deprecated (and
            // always used UTF-8 as its "encoding" was really about how bytes
            // got escaped, not which characters got escaped). The modern
            // equivalent takes an explicit allowed-character set instead;
            // URLPathAllowedCharacterSet keeps "/" unescaped, matching the
            // old behavior for these path-like arguments.
            NSString *escaped =
                [arg stringByAddingPercentEncodingWithAllowedCharacters:
                    [NSCharacterSet URLPathAllowedCharacterSet]];
            NSURL *url = [NSURL URLWithString:escaped relativeToURL:pwdUrl];
            [urls addObject:url];
        }
        MPCollectForMacDown(urls);

        // Launch MacDown. launchAppWithBundleIdentifier:options:
        // additionalEventParamDescriptor:launchIdentifier: and
        // NSWorkspaceLaunchDefault are both deprecated (macOS 11); the
        // replacement API takes an app URL rather than a bundle identifier,
        // so resolve that first.
        NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
        NSURL *appURL =
            [workspace URLForApplicationWithBundleIdentifier:kMPApplicationBundleIdentifier];
        if (appURL)
        {
            NSWorkspaceOpenConfiguration *configuration =
                [NSWorkspaceOpenConfiguration configuration];
            [workspace openApplicationAtURL:appURL configuration:configuration
                           completionHandler:nil];
        }
    }
    return EXIT_SUCCESS;
}

