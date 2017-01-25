//
//  MPArgumentProcessor.m
//  MacDown
//
//  Created by Tzu-ping Chung on 02/12.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPArgumentProcessor.h"
#import <GBCli/GBCli.h>
#import "MPGlobals.h"


@interface MPArgumentProcessor ()

@property (strong) GBCommandLineParser *parser;
@property (strong) GBOptionsHelper *options;
@property (strong) GBSettings *settings;

@end


@implementation MPArgumentProcessor

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    // Init options.
    GBOptionsHelper *options = [[GBOptionsHelper alloc] init];
    options.applicationVersion = ^{
        return [NSString stringWithUTF8String:kMPApplicationShortVersion];
    };
    options.applicationBuild = ^{
        return [NSString stringWithUTF8String:kMPApplicationBundleVersion];
    };
    options.applicationName = ^{ return kMPApplicationName; };
    options.printHelpHeader = ^{
        NSString *fmt =
            @"usage: %@ [file ...]\n\nOptions:";
        return [NSString stringWithFormat:fmt, kMPCommandName];
    };
    [options registerOption:'v' long:kMPVersionKey
                description:@"Print the version and exit."
                      flags:GBOptionNoValue];
    [options registerOption:'h' long:kMPHelpKey
                description:@"Print this help message and exit."
                      flags:GBOptionNoValue];
    self.options = options;

    self.settings = [[GBSettings alloc] initWithName:@"command-line"
                                              parent:nil];

    // Create parser and parse.
    GBCommandLineParser *parser = [[GBCommandLineParser alloc] init];
    [parser registerSettings:self.settings];
    [parser registerOptions:self.options];
    self.parser = parser;

    [self.parser parseOptionsUsingDefaultArguments];

    return self;
}

- (BOOL)printsHelp
{
    return [self.settings boolForKey:kMPHelpKey];
}

- (BOOL)printsVersion
{
    return [self.settings boolForKey:kMPVersionKey];
}

- (NSArray *)arguments
{
    return self.parser.arguments;
}

- (void)printHelp:(BOOL)shouldExit
{
    [self.options printHelp];
    if (shouldExit)
        exit(EXIT_SUCCESS);
}

- (void)printVersion:(BOOL)shouldExit
{
    [self.options printVersion];
    if (shouldExit)
        exit(EXIT_SUCCESS);
}

@end
