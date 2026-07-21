#import "MPRMarkdownParser.h"

@implementation MPRMarkdownCodeBlock
@end

@implementation MPRMarkdownParser

- (NSArray<MPRMarkdownCodeBlock *> *)parseCodeBlocks:(NSString *)rmarkdownContent {
    NSMutableArray *codeBlocks = [NSMutableArray array];

    NSRegularExpression *codeBlockRegex = [NSRegularExpression
        regularExpressionWithPattern:@"```\\{([^}]*)\\}\\n([\\s\\S]*?)\\n```"
                             options:0
                               error:nil];

    NSArray *matches = [codeBlockRegex matchesInString:rmarkdownContent
                                               options:0
                                                 range:NSMakeRange(0, rmarkdownContent.length)];

    for (NSTextCheckingResult *match in matches) {
        MPRMarkdownCodeBlock *block = [[MPRMarkdownCodeBlock alloc] init];

        NSString *fenceInfo = [rmarkdownContent substringWithRange:[match rangeAtIndex:1]];
        block.code = [rmarkdownContent substringWithRange:[match rangeAtIndex:2]];
        block.language = [self extractLanguage:fenceInfo];
        block.options = [self parseChunkOptions:fenceInfo];
        block.range = match.range;

        [codeBlocks addObject:block];
    }

    return [codeBlocks copy];
}

- (NSString *)extractMarkdownWithoutCodeBlocks:(NSString *)rmarkdownContent {
    NSRegularExpression *codeBlockRegex = [NSRegularExpression
        regularExpressionWithPattern:@"```\\{[^}]*\\}\\n[\\s\\S]*?\\n```"
                             options:0
                               error:nil];

    NSString *markdown = [codeBlockRegex stringByReplacingMatchesInString:rmarkdownContent
                                                                  options:0
                                                                    range:NSMakeRange(0, rmarkdownContent.length)
                                                            withTemplate:@""];
    return markdown;
}

- (BOOL)isRCodeBlock:(NSString *)fenceInfo {
    NSString *language = [self extractLanguage:fenceInfo];
    return [language.lowercaseString isEqualToString:@"r"] ||
           [fenceInfo.lowercaseString containsString:@"r,"];
}

- (NSString *)extractLanguage:(NSString *)fenceInfo {
    if (!fenceInfo || fenceInfo.length == 0) {
        return @"";
    }

    NSArray *parts = [fenceInfo componentsSeparatedByString:@","];
    NSString *firstPart = [parts.firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    return firstPart ?: @"";
}

- (NSDictionary *)parseChunkOptions:(NSString *)fenceInfo {
    NSMutableDictionary *options = [NSMutableDictionary dictionary];

    if (!fenceInfo || fenceInfo.length == 0) {
        return options;
    }

    NSArray *parts = [fenceInfo componentsSeparatedByString:@","];

    for (NSString *part in parts) {
        NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        NSRange equalsRange = [trimmed rangeOfString:@"="];
        if (equalsRange.location != NSNotFound) {
            NSString *key = [trimmed substringToIndex:equalsRange.location];
            NSString *value = [trimmed substringFromIndex:equalsRange.location + equalsRange.length];

            key = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            value = [value stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"'\""]];

            options[key] = value;
        } else if ([trimmed length] > 0 && ![trimmed isEqualToString:@"r"]) {
            options[trimmed] = @"TRUE";
        }
    }

    return [options copy];
}

@end
