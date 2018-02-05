//
//  MPUtilities.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 8/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPUtilities.h"
#import "NSString+Lookup.h"
#import <JavaScriptCore/JavaScriptCore.h>

NSString * const kMPStylesDirectoryName = @"Styles";
NSString * const kMPStyleFileExtension = @"css";
NSString * const kMPThemesDirectoryName = @"Themes";
NSString * const kMPThemeFileExtension = @"style";
NSString * const kMPPlugInsDirectoryName = @"PlugIns";
NSString * const kMPPlugInFileExtension = @"plugin";

// These are the Touch Bar item identifiers for the
// editorView and webView touchbars

const NSTouchBarItemIdentifier MPTouchBarItemFormattingIdentifier =
    @"com.uranusjr.macdown.touchbar.formatting";
const NSTouchBarItemIdentifier MPTouchBarItemStrongIdentifier =
    @"com.uranusjr.macdown.touchbar.strong";
const NSTouchBarItemIdentifier MPTouchBarItemEmphasisIdentifier =
    @"com.uranusjr.macdown.touchbar.emphasis";
const NSTouchBarItemIdentifier MPTouchBarItemUnderlineIdentifier =
    @"com.uranusjr.macdown.touchbar.underline";
const NSTouchBarItemIdentifier MPTouchBarItemCodeIdentifier =
    @"com.uranusjr.macdown.touchbar.code";
const NSTouchBarItemIdentifier MPTouchBarItemCommentIdentifier =
    @"com.uranusjr.macdown.touchbar.comment";
const NSTouchBarItemIdentifier MPTouchBarItemBlockquoteIdentifier =
    @"com.uranusjr.macdown.touchbar.blockquote";
const NSTouchBarItemIdentifier MPTouchBarItemStrikeIdentifier =
    @"com.uranusjr.macdown.touchbar.strikethrough";
const NSTouchBarItemIdentifier MPTouchBarItemHighlightIdentifier =
    @"com.uranusjr.macdown.touchbar.highlight";

const NSTouchBarItemIdentifier MPTouchBarItemHeadingPopIdentifier =
    @"com.uranusjr.macdown.touchbar.headingPopover";
const NSTouchBarItemIdentifier MPTouchBarItemH1Identifier =
	@"com.uranusjr.macdown.touchbar.h1";
const NSTouchBarItemIdentifier MPTouchBarItemH2Identifier =
	@"com.uranusjr.macdown.touchbar.h2";
const NSTouchBarItemIdentifier MPTouchBarItemH3Identifier =
	@"com.uranusjr.macdown.touchbar.h3";
const NSTouchBarItemIdentifier MPTouchBarItemH4Identifier =
	@"com.uranusjr.macdown.touchbar.h4";
const NSTouchBarItemIdentifier MPTouchBarItemH5Identifier =
	@"com.uranusjr.macdown.touchbar.h5";
const NSTouchBarItemIdentifier MPTouchBarItemH6Identifier =
	@"com.uranusjr.macdown.touchbar.h6";
const NSTouchBarItemIdentifier MPTouchBarItemH0Identifier =
	@"com.uranusjr.macdown.touchbar.h0";

const NSTouchBarItemIdentifier MPTouchBarItemLinkIdentifier =
    @"com.uranusjr.macdown.touchbar.link";
const NSTouchBarItemIdentifier MPTouchBarItemImageIdentifier =
    @"com.uranusjr.macdown.touchbar.image";

const NSTouchBarItemIdentifier MPTouchBarItemListsIdentifier =
    @"com.uranusjr.macdown.touchbar.lists";
const NSTouchBarItemIdentifier MPTouchBarItemOrderedListIdentifier =
    @"com.uranusjr.macdown.touchbar.list-ordered";
const NSTouchBarItemIdentifier MPTouchBarItemSimpleListIdentifier =
    @"com.uranusjr.macdown.touchbar.list-simple";

const NSTouchBarItemIdentifier MPTouchBarItemShiftIdentifier =
    @"com.uranusjr.macdown.touchbar.shift";
const NSTouchBarItemIdentifier MPTouchBarItemShiftRightIdentifier =
    @"com.uranusjr.macdown.touchbar.shift-right";
const NSTouchBarItemIdentifier MPTouchBarItemShiftLeftIdentifier =
    @"com.uranusjr.macdown.touchbar.shift-left";

const NSTouchBarItemIdentifier MPTouchBarItemCopyHTMLIdentifier =
    @"com.uranusjr.macdown.touchbar.copyHTML";

const NSTouchBarItemIdentifier MPTouchBarItemLayoutPopIdentifier =
    @"com.uranusjr.macdown.touchbar.layoutPopover";
const NSTouchBarItemIdentifier MPTouchBarItemLayoutIdentifier =
    @"com.uranusjr.macdown.touchbar.layout";
const NSTouchBarItemIdentifier MPTouchBarItemHideEditorIdentifier =
    @"com.uranusjr.macdown.touchbar.layout-hideEditor";
const NSTouchBarItemIdentifier MPTouchBarItemEqualSplitEditorIdentifier =
    @"com.uranusjr.macdown.touchbar.layout-equalSplitEditor";
const NSTouchBarItemIdentifier MPTouchBarItemHidePreviewIdentifier =
    @"com.uranusjr.macdown.touchbar.layout-hidePreview";

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

NSString *(^MPFileNameHasExtensionProcessor(NSString *ext))(NSString *path)
{
    id block = ^(NSString *absPath) {
        NSFileManager *manager = [NSFileManager defaultManager];
        NSString *name = absPath.lastPathComponent;
        NSString *processed = nil;
        if ([name hasExtension:ext] && [manager fileExistsAtPath:absPath])
            processed = name.stringByDeletingPathExtension;
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
    if (![name hasExtension:kMPStyleFileExtension])
        name = [name stringByAppendingPathExtension:kMPStyleFileExtension];
    NSString *path = MPPathToDataFile(name, kMPStylesDirectoryName);
    return path;
}

NSString *MPThemePathForName(NSString *name)
{
    if (![name hasExtension:kMPThemeFileExtension])
        name = [name stringByAppendingPathExtension:kMPThemeFileExtension];
    NSString *path = MPPathToDataFile(name, kMPThemesDirectoryName);
    return path;
}

NSURL *MPHighlightingThemeURLForName(NSString *name)
{
    name = [NSString stringWithFormat:@"prism-%@", [name lowercaseString]];
    if ([name hasExtension:@"css"])
        name = name.stringByDeletingPathExtension;

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

NSDictionary *MPGetDataMap(NSString *name)
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *filePath = [bundle pathForResource:name ofType:@"map"
                                     inDirectory:@"Data"];
    return [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
}

id MPGetObjectFromJavaScript(NSString *code, NSString *variableName)
{
    if (!code.length)
        return nil;

    id object = nil;
    JSGlobalContextRef cxt = NULL;
    JSStringRef js = NULL;
    JSStringRef varn = NULL;
    JSStringRef jsonr = NULL;

    do {
        JSValueRef exc = NULL;

        cxt = JSGlobalContextCreate(NULL);
        js = JSStringCreateWithCFString((__bridge CFStringRef)code);
        JSEvaluateScript(cxt, js, NULL, NULL, 0, &exc);
        if (exc)
            break;

        varn = JSStringCreateWithUTF8CString([variableName UTF8String]);
        JSObjectRef global = JSContextGetGlobalObject(cxt);
        JSValueRef val = JSObjectGetProperty(cxt, global, varn, &exc);

        // JavaScript Object -> JSON -> Foundation Object.
        // Not the best way to do this, but enough for our purpose.
        jsonr = JSValueCreateJSONString(cxt, val, 0, &exc);
        if (exc)
            break;
        size_t sz = JSStringGetLength(jsonr) + 1;   // NULL terminated.
        char *buffer = (char *)malloc(sz * sizeof(char));
        JSStringGetUTF8CString(jsonr, buffer, sz);
        NSData *data = [NSData dataWithBytesNoCopy:buffer length:sz - 1
                                      freeWhenDone:YES];
        object = [NSJSONSerialization JSONObjectWithData:data options:0
                                                   error:NULL];
    } while (0);

    if (jsonr)
        JSStringRelease(jsonr);
    if (varn)
        JSStringRelease(varn);
    if (cxt)
        JSGlobalContextRelease(cxt);
    if (js)
        JSStringRelease(js);
    return object;
}

