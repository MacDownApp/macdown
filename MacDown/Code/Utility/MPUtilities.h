//
//  MPUtilities.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 8/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, MPAssetsOption)
{
    MPAssetsNone      = 0,
    MPAssetsStripPath = 1,
    MPAssetsEmbedded  = 2,
    MPAssetsFullLink  = 3,
};

extern NSString * const kMPApplicationName;
extern NSString * const kMPStylesDirectoryName;
extern NSString * const kMPStyleFileExtension;
extern NSString * const kMPThemesDirectoryName;
extern NSString * const kMPThemeFileExtension;

NSString *MPDataDirectory(NSString *relativePath);
NSString *MPPathToDataFile(NSString *name, NSString *dirPath);

NSArray *MPListEntriesForDirectory(
    NSString *dirName, NSString *(^processor)(NSString *absolutePath)
);

// Block factory for MPListEntriesForDirectory
NSString *(^MPFileNameHasSuffixProcessor(NSString *suffix))(NSString *path);

BOOL MPCharacterIsWhitespace(unichar character);
BOOL MPCharacterIsNewline(unichar character);
BOOL MPStringIsNewline(NSString *str);

NSString *MPStylePathForName(NSString *name);
NSString *MPThemePathForName(NSString *name);
NSString *MPReadFileOfPath(NSString *path);
