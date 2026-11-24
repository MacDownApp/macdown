//
//  NSString+Emoji.m
//  MacDown
//

#import "NSString+Emoji.h"
#import "NSJSONSerialization+File.h"

static NSDictionary *MPEmojiShortcodes()
{
    static NSDictionary *shortcodes = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"emoji"
                                             withExtension:@"json"
                                              subdirectory:@"Data"];
        shortcodes = [NSJSONSerialization JSONObjectWithFileAtURL:url
                                                          options:0
                                                            error:NULL];
    });
    return shortcodes;
}

@implementation NSString (Emoji)

- (NSString *)stringByReplacingEmojiShortcodes
{
    // Tags and <pre>/<code> blocks are matched too so that they are passed
    // through untouched; only shortcodes in plain text are replaced.
    static NSRegularExpression *regex = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:
            @"<(pre|code|script|style)\\b[^>]*>.*?</\\1\\s*>|<[^>]*>|:([a-z0-9_+-]+):"
            options:NSRegularExpressionCaseInsensitive |
                    NSRegularExpressionDotMatchesLineSeparators
            error:NULL];
    });

    NSDictionary *shortcodes = MPEmojiShortcodes();
    NSMutableString *result = [self mutableCopy];
    NSArray *matches = [regex matchesInString:self options:0
                                        range:NSMakeRange(0, self.length)];
    // Iterate backwards so earlier replacement ranges stay valid.
    for (NSTextCheckingResult *match in matches.reverseObjectEnumerator)
    {
        NSRange nameRange = [match rangeAtIndex:2];
        if (nameRange.location == NSNotFound)
            continue;
        NSString *emoji = shortcodes[[self substringWithRange:nameRange]];
        if (emoji)
            [result replaceCharactersInRange:match.range withString:emoji];
    }
    return result;
}

@end
