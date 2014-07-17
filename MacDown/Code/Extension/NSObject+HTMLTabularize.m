//
//  NSObject+HTMLTabularize.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 13/7.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "NSObject+HTMLTabularize.h"
#import <HBHandlebars/HBHandlebars.h>
#import <M13OrderedDictionary/M13OrderedDictionary.h>


@implementation NSObject (HTMLTabularize)

- (NSString *)HTMLTable
{
    static HBEscapingFunction escape = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        escape = [HBEscapingFunctions htmlEscapingFunction];
    });
    return escape(self.description);
}

+ (NSArray *)validKeysForHandlebars
{
    return @[@"HTMLTable"];
}

@end


@implementation NSNull (HTMLTabularize)

- (NSString *)HTMLTable
{
    return @"";
}

@end


@implementation NSArray (HTMLTabularize)

- (NSString *)HTMLTable
{
    static NSString *template =
        @"<table><tbody><tr>"
        @"{{#each objects}}<td>{{{HTMLTable this}}}</td>{{/each}}"
        @"</tr></tbody></table>";
    static NSDictionary *helpers = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        helpers = @{@"HTMLTable": ^NSString *(HBHelperCallingInfo *info) {
            return [info.positionalParameters[0] HTMLTable];
        }};
    });
    NSDictionary *context = @{@"objects": self};
    return [HBHandlebars renderTemplateString:template withContext:context
                             withHelperBlocks:helpers error:NULL];
}

@end


@implementation NSDictionary (HTMLTabularize)

- (NSString *)HTMLTable
{
    static NSString *template =
        @"<table><thead><tr>"
        @"{{#each keys}}<th>{{{HTMLTable this}}}</th>{{/each}}"
        @"</tr></thead><tbody><tr>"
        @"{{#each objects}}<td>{{{HTMLTable this}}}</td>{{/each}}"
        @"</tr></tbody></table>";
    static NSDictionary *helpers = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        helpers = @{@"HTMLTable": ^NSString *(HBHelperCallingInfo *info) {
            return [info.positionalParameters[0] HTMLTable];
        }};
    });
    NSArray *keys = self.allKeys;
    NSMutableArray *objects = [NSMutableArray array];
    for (id key in keys)
        [objects addObject:self[key]];
    NSDictionary *context = @{@"keys": keys, @"objects": objects};
    return [HBHandlebars renderTemplateString:template withContext:context
                             withHelperBlocks:helpers error:NULL];
}

@end


@implementation M13OrderedDictionary (HTMLTabularize)

- (NSString *)HTMLTable
{
    static NSString *template =
        @"<table><thead><tr>"
        @"{{#each keys}}<th>{{{HTMLTable this}}}</th>{{/each}}"
        @"</tr></thead><tbody><tr>"
        @"{{#each objects}}<td>{{{HTMLTable this}}}</td>{{/each}}"
        @"</tr></tbody></table>";
    static NSDictionary *helpers = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        helpers = @{@"HTMLTable": ^NSString *(HBHelperCallingInfo *info) {
            return [info.positionalParameters[0] HTMLTable];
        }};
    });
    NSDictionary *context = @{@"keys": self.allKeys,
                              @"objects": self.allObjects};
    return [HBHandlebars renderTemplateString:template withContext:context
                             withHelperBlocks:helpers error:NULL];
}

@end