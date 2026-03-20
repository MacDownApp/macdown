//
//  MPGlobals.h
//  MacDown
//
//  Created by Tzu-ping Chung on 02/12.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "version.h"

// These should match the main bundle's values.
static NSString * const kMPApplicationName = @"Markly";

#ifdef DEBUG
static NSString * const kMPApplicationBundleIdentifier = @"com.markly.app-debug";
#else
static NSString * const kMPApplicationBundleIdentifier = @"com.markly.app";
#endif

static NSString * const kMPApplicationSuiteName = @"com.markly.app";

static NSString * const MPCommandInstallationPath = @"/usr/local/bin/markly";
static NSString * const kMPCommandName = @"markly";

static NSString * const kMPHelpKey = @"help";
static NSString * const kMPVersionKey = @"version";

static NSString * const kMPFilesToOpenKey = @"filesToOpenOnNextLaunch";
static NSString * const kMPPipedContentFileToOpen = @"pipedContentFileToOpenOnNextLaunch";
static NSString * const kMPPerFileViewModeKey = @"perFileViewModes";
