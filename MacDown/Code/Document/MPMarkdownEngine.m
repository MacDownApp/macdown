//
//  MPMarkdownEngine.m
//  MacDown
//

#import "MPMarkdownEngine.h"


@implementation MPMarkdownRenderOptions

static NSArray<NSString *> *MPOptionKeys(void)
{
    static NSArray *keys;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        keys = @[@"tables", @"fencedCode", @"footnotes", @"autolink",
                 @"strikethrough", @"underline", @"highlight", @"quote",
                 @"superscript", @"intraEmphasis", @"math",
                 @"mathInlineDollar", @"taskList", @"lineNumbers", @"hardWrap",
                 @"codeBlockInformation", @"smartyPants", @"rendersTOC",
                 @"detectsFrontMatter"];
    });
    return keys;
}

- (id)copyWithZone:(NSZone *)zone
{
    MPMarkdownRenderOptions *copy = [[[self class] allocWithZone:zone] init];
    for (NSString *key in MPOptionKeys())
        [copy setValue:[self valueForKey:key] forKey:key];
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[MPMarkdownRenderOptions class]])
        return NO;
    for (NSString *key in MPOptionKeys())
    {
        if (![[self valueForKey:key] isEqual:[object valueForKey:key]])
            return NO;
    }
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger h = 0;
    for (NSString *key in MPOptionKeys())
        h = h * 31 + [[self valueForKey:key] hash];
    return h;
}

@end


@implementation MPMarkdownResult

- (instancetype)initWithHTML:(NSString *)html
                   languages:(NSArray<NSString *> *)languages
{
    self = [super init];
    if (!self)
        return nil;
    _html = [html copy];
    _languages = [languages copy];
    return self;
}

@end
