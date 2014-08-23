//
//  MPUtilities.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 8/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPUtilities.h"
#import <JavaScriptCore/JavaScriptCore.h>

NSString * const kMPStylesDirectoryName = @"Styles";
NSString * const kMPStyleFileExtension = @".css";
NSString * const kMPThemesDirectoryName = @"Themes";
NSString * const kMPThemeFileExtension = @".style";

static NSString *MPDataRootDirectory()
{
    static NSString *path = nil;
    if (!path)
    {
        NSArray *paths =
            NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                NSUserDomainMask, YES);
        NSCAssert(paths.count > 0,
                  @"Cannot find directory for NSApplicationSupportDirectory.");
        NSDictionary *infoDictionary = [NSBundle mainBundle].infoDictionary;
        path = [NSString pathWithComponents:@[paths[0],
                                              infoDictionary[@"CFBundleName"]]];
    }
    return path;
}

NSString *MPDataDirectory(NSString *relativePath)
{
    if (!relativePath)
        return MPDataRootDirectory();
    return [NSString pathWithComponents:@[MPDataRootDirectory(), relativePath]];
}

NSString *MPPathToDataFile(NSString *name, NSString *dirPath)
{
    return [NSString pathWithComponents:@[MPDataDirectory(dirPath),
                                          name]];
}

NSArray *MPListEntriesForDirectory(
    NSString *dirName, NSString *(^processor)(NSString *absolutePath))
{
    NSString *dirPath = MPDataDirectory(dirName);

    NSError *error = nil;
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *fileNames = [manager contentsOfDirectoryAtPath:dirPath
                                                      error:&error];
    if (error || !fileNames.count)
        return @[];

    NSMutableArray *items = [[NSMutableArray alloc] init];
    for (NSString *fileName in fileNames)
    {
        NSString *item = [NSString pathWithComponents:@[dirPath, fileName]];
        if (processor)
            item = processor(item);
        if (item)
            [items addObject:item];
    }
    return [items copy];
}

NSString *(^MPFileNameHasSuffixProcessor(NSString *suffix))(NSString *path)
{
    id block = ^(NSString *absPath) {
        NSFileManager *manager = [NSFileManager defaultManager];
        NSString *name = absPath.lastPathComponent;
        NSString *processed = nil;
        if ([name hasSuffix:suffix] && [manager fileExistsAtPath:absPath])
        {
            NSUInteger end = name.length - suffix.length;
            processed = [name substringToIndex:end];
        }
        return processed;
    };
    return block;
}

BOOL MPCharacterIsWhitespace(unichar character)
{
    static NSCharacterSet *whitespaces = nil;
    if (!whitespaces)
        whitespaces = [NSCharacterSet whitespaceCharacterSet];
    return [whitespaces characterIsMember:character];
}

BOOL MPCharacterIsNewline(unichar character)
{
    static NSCharacterSet *newlines = nil;
    if (!newlines)
        newlines = [NSCharacterSet newlineCharacterSet];
    return [newlines characterIsMember:character];
}

BOOL MPStringIsNewline(NSString *str)
{
    if (str.length != 1)
        return NO;
    return MPCharacterIsNewline([str characterAtIndex:0]);
}

NSString *MPStylePathForName(NSString *name)
{
    if (!name)
        return nil;
    if (![name hasSuffix:kMPStyleFileExtension])
        name = [NSString stringWithFormat:@"%@%@", name, kMPStyleFileExtension];
    NSString *path = MPPathToDataFile(name, kMPStylesDirectoryName);
    return path;
}

NSString *MPThemePathForName(NSString *name)
{
    if (![name hasSuffix:kMPThemeFileExtension])
        name = [NSString stringWithFormat:@"%@%@", name, kMPThemeFileExtension];
    NSString *path = MPPathToDataFile(name, kMPThemesDirectoryName);
    return path;
}

NSURL *MPHighlightingThemeURLForName(NSString *name)
{
    name = [NSString stringWithFormat:@"prism-%@", [name lowercaseString]];
    if ([name hasSuffix:@".css"])
        name = [name substringToIndex:name.length - 4];

    NSBundle *bundle = [NSBundle mainBundle];
    NSURL *url = [bundle URLForResource:name withExtension:@"css"
                           subdirectory:@"Prism/themes"];

    // Safty net: file not found, use default.
    if (!url)
    {
        url = [bundle URLForResource:@"prism" withExtension:@"css"
                        subdirectory:@"Prism/themes"];
    }
    return url;
}

NSString *MPReadFileOfPath(NSString *path)
{
    NSError *error = nil;
    NSString *s = [NSString stringWithContentsOfFile:path
                                            encoding:NSUTF8StringEncoding
                                               error:&error];
    if (error)
        return @"";
    return s;
}

id MPGetObjectFromJavaScript(NSString *code, NSString *variableName)
{
    if (!code.length)
        return nil;

    id object = nil;
    JSGlobalContextRef cxt = NULL;
    JSStringRef varn = NULL;
    JSValueRef exc = NULL;

    do {
        cxt = JSGlobalContextCreate(NULL);
        JSStringRef js = JSStringCreateWithCFString((__bridge CFStringRef)code);
        JSObjectRef glb = JSContextGetGlobalObject(cxt);
        JSEvaluateScript(cxt, js, NULL, NULL, 0, &exc);
        if (exc)
            break;

        varn = JSStringCreateWithUTF8CString([variableName UTF8String]);
        JSValueRef val = JSObjectGetProperty(cxt, glb, varn, &exc);

        JSStringRef jsonr = JSValueCreateJSONString(cxt, val, 0, &exc);
        if (exc)
            break;

        size_t sz = JSStringGetLength(jsonr) + 1;   // NULL terminated.
        char *buffer = malloc(sz);
        JSStringGetUTF8CString(jsonr, buffer, sz);
        NSData *data = [NSData dataWithBytes:buffer length:sz - 1];
        object = [NSJSONSerialization JSONObjectWithData:data options:0
                                                   error:NULL];
        free(buffer);
    } while (0);

    if (varn)
        JSStringRelease(varn);
    if (cxt)
        JSGlobalContextRelease(cxt);
    return object;
}

