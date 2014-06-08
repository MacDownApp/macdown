//
//  MPUtilities.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 8/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const MPApplicationName;
extern NSString * const MPStylesDirectoryName;
extern NSString * const MPStyleFileExtension;
extern NSString * const MPThemesDirectoryName;
extern NSString * const MPThemeFileExtension;

NSString *MPGetDataRootPath();
NSString *MPGetDataDirectoryPath(NSString *relativePath);
NSString *MPGetDataFilePath(NSString *name, NSString *dirPath);