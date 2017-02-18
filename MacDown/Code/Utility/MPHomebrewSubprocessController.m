//
//  MPHomebrewSubprocessController.m
//  MacDown
//
//  Created by Tzu-ping Chung on 18/2.
//  Copyright © 2017 Tzu-ping Chung . All rights reserved.
//

#import "MPHomebrewSubprocessController.h"


@interface MPHomebrewSubprocessController ()

@property (readonly) NSTask *task;
@property (readwrite) void(^completionHandler)(NSString *);

@end


@implementation MPHomebrewSubprocessController

- (instancetype)initWithArguments:(NSArray *)args
{
    self = [super init];
    if (!self)
        return nil;

    NSPipe *stdoutPipe = [[NSPipe alloc] init];
    NSFileHandle *stdoutReadHandle = stdoutPipe.fileHandleForReading;

    _task = [[NSTask alloc] init];
    _task.launchPath = @"brew";
    if (args)
        _task.arguments = args;
    _task.standardOutput = stdoutPipe;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(homebrewReadDidComplete:)
                   name:NSFileHandleReadToEndOfFileCompletionNotification
                 object:stdoutReadHandle];
    [stdoutReadHandle readToEndOfFileInBackgroundAndNotify];

    return self;
}

- (instancetype)init
{
    return [self initWithArguments:nil];
}

- (void)dealloc
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self
                      name:NSFileHandleReadToEndOfFileCompletionNotification
                    object:nil];
}

- (void)runWithCompletionHandler:(void(^)(NSString *))handler
{
    self.completionHandler = handler;
    @try
    {
        [self.task launch];
    }
    @catch (NSException *exception)     // Homebrew not installed.
    {
        if (handler)
            handler(nil);
    }
}

- (void)homebrewReadDidComplete:(NSNotification *)notification
{
    NSData *outData = notification.userInfo[NSFileHandleNotificationDataItem];
    NSString *output = [[NSString alloc] initWithData:outData
                                             encoding:NSUTF8StringEncoding];
    if (self.completionHandler)
        self.completionHandler(output);
}

@end


void MPDetectHomebrewPrefixWithCompletionhandler(void(^handler)(NSString *))
{
    NSArray *args = @[@"--prefix"];
    MPHomebrewSubprocessController *c =
        [[MPHomebrewSubprocessController alloc] initWithArguments:args];
    [c runWithCompletionHandler:handler];
}

