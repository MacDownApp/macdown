//
//  MPUtilities.m
//  MarkPad
//
//  Created by Tzu-ping Chung  on 8/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPUtilities.h"

NSString * const MPApplicationName = @"MarkPad";
NSString * const MPStylesDirectoryName = @"Styles";
NSString * const MPStyleFileExtension = @".css";
NSString * const MPThemesDirectoryName = @"Themes";
NSString * const MPThemeFileExtension = @".style";

NSString *MPGetDataRootPath()
{
    NSArray *paths =
        NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                            NSUserDomainMask, YES);
    NSCAssert(paths.count > 0,
              @"Cannot find directory for NSApplicationSupportDirectory.");
    NSString *path = [NSString pathWithComponents:@[paths[0],
                                                    MPApplicationName]];
    return path;
}

NSString *MPGetDataDirectoryPath(NSString *relativePath)
{
    return [NSString pathWithComponents:@[MPGetDataRootPath(), relativePath]];
}

NSString *MPGetDataFilePath(NSString *name, NSString *dirPath)
{
    if (!dirPath)
        return [NSString pathWithComponents:@[MPGetDataRootPath(), name]];
    return [NSString pathWithComponents:@[MPGetDataDirectoryPath(dirPath),
                                          name]];
}