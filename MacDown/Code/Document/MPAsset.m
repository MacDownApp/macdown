//
//  MPAsset.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 29/6.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPAsset.h"
#import "DMTemplateEngine.h"
#import "MPUtilities.h"


NSString * const kMPCSSType = @"text/css";
NSString * const kMPJavaScriptType = @"text/javascript";
NSString * const kMPMathJaxConfigType = @"text/x-mathjax-config";


@interface MPAsset ()
@property (strong) NSURL *url;
@property (copy) NSString *typeName;
@end


@implementation MPAsset

+ (instancetype)assetWithURL:(NSURL *)url andType:(NSString *)typeName
{
    return [[self alloc] initWithURL:url andType:typeName];
}

- (instancetype)initWithURL:(NSURL *)url andType:(NSString *)typeName
{
    self = [super init];
    if (!self)
        return nil;
    self.url = [url copy];
    self.typeName = typeName;
    return self;
}

- (instancetype)init
{
    return [self initWithURL:nil andType:@"text/plain"];
}

- (NSString *)templateForOption:(MPAssetOption)option
{
    NSString *reason =
        [NSString stringWithFormat:@"Method %@ requires overriding",
                                   NSStringFromSelector(_cmd)];
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:reason userInfo:nil];
}

- (NSString *)htmlForOption:(MPAssetOption)option
{
    NSMutableDictionary *context =
        [NSMutableDictionary dictionaryWithObject:self.typeName
                                           forKey:@"typeName"];
    switch (option)
    {
        case MPAssetNone:
            break;
        case MPAssetEmbedded:
            if (self.url.isFileURL)
            {
                context[@"content"] = MPReadFileOfPath(self.url.path);
                break;
            }
            // Non-file URLs fallthrough to be treated as full links.
        case MPAssetFullLink:
            context[@"url"] = self.url.absoluteString;
            break;
    }

    NSString *template = [self templateForOption:option];
    if (!template || !context.count)
        return nil;

    DMTemplateEngine *engine = [DMTemplateEngine engineWithTemplate:template];
    NSString *result = [engine renderAgainst:context];
    return result;
}

@end


@implementation MPStyleSheet

+ (instancetype)CSSWithURL:(NSURL *)url
{
    return [super assetWithURL:url andType:kMPCSSType];
}

- (NSString *)templateForOption:(MPAssetOption)option
{
    NSString *template = nil;
    switch (option)
    {
        case MPAssetNone:
            break;
        case MPAssetEmbedded:
            if (self.url.isFileURL)
            {
                template = (@"<style type=\"{% typeName %}\">\n"
                            @"{% content %}\n</style>");
                break;
            }
            // Non-file URLs fallthrough to be treated as full links.
        case MPAssetFullLink:
            template = (@"<link rel=\"stylesheet\" type=\"{% typeName %}\" "
                        @"href=\"{% url %}\">");
            break;
    }
    return template;
}

@end


@implementation MPScript

+ (instancetype)javaScriptWithURL:(NSURL *)url
{
    return [super assetWithURL:url andType:kMPJavaScriptType];
}

- (NSString *)templateForOption:(MPAssetOption)option
{
    NSString *template = nil;
    switch (option)
    {
        case MPAssetNone:
            break;
        case MPAssetEmbedded:
            if (self.url.isFileURL)
            {
                template = (@"<script type=\"{% typeName %}\">\n"
                            @"{% content %}\n</script>");
                break;
            }
            // Non-file URLs fall-through to be treated as full links.
        case MPAssetFullLink:
            template = (@"<script type=\"{% typeName %}\" src=\"{% url %}\">"
                        @"</script>");
            break;
    }
    return template;
}

@end


@implementation MPEmbeddedScript

- (NSString *)htmlForOption:(MPAssetOption)option
{
    if (option == MPAssetFullLink)
        option = MPAssetEmbedded;
    return [super htmlForOption:option];
}

@end
