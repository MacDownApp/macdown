#import "MPLaTeXParser.h"

@implementation MPLaTeXParser

- (NSDictionary *)parseDocumentMetadata:(NSString *)texContent {
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];

    NSRegularExpression *titleRegex = [NSRegularExpression
        regularExpressionWithPattern:@"\\\\title\\{([^}]*)\\}"
                             options:0
                               error:nil];
    NSArray *titleMatches = [titleRegex matchesInString:texContent
                                               options:0
                                                 range:NSMakeRange(0, texContent.length)];
    if (titleMatches.count > 0) {
        NSRange titleRange = [titleMatches[0] rangeAtIndex:1];
        metadata[@"title"] = [texContent substringWithRange:titleRange];
    }

    NSRegularExpression *authorRegex = [NSRegularExpression
        regularExpressionWithPattern:@"\\\\author\\{([^}]*)\\}"
                             options:0
                               error:nil];
    NSArray *authorMatches = [authorRegex matchesInString:texContent
                                                 options:0
                                                   range:NSMakeRange(0, texContent.length)];
    if (authorMatches.count > 0) {
        NSRange authorRange = [authorMatches[0] rangeAtIndex:1];
        metadata[@"author"] = [texContent substringWithRange:authorRange];
    }

    NSRegularExpression *dateRegex = [NSRegularExpression
        regularExpressionWithPattern:@"\\\\date\\{([^}]*)\\}"
                             options:0
                               error:nil];
    NSArray *dateMatches = [dateRegex matchesInString:texContent
                                             options:0
                                               range:NSMakeRange(0, texContent.length)];
    if (dateMatches.count > 0) {
        NSRange dateRange = [dateMatches[0] rangeAtIndex:1];
        metadata[@"date"] = [texContent substringWithRange:dateRange];
    }

    return [metadata copy];
}

- (NSString *)extractPreamble:(NSString *)texContent {
    NSRange documentBeginRange = [texContent rangeOfString:@"\\begin{document}"];

    if (documentBeginRange.location == NSNotFound) {
        return texContent;
    }

    return [texContent substringToIndex:documentBeginRange.location];
}

- (BOOL)isStandaloneDocument:(NSString *)texContent {
    BOOL hasDocumentclass = [texContent containsString:@"\\documentclass"];
    BOOL hasBeginDocument = [texContent containsString:@"\\begin{document}"];
    BOOL hasEndDocument = [texContent containsString:@"\\end{document}"];

    return hasDocumentclass && hasBeginDocument && hasEndDocument;
}

- (NSString *)wrapContentAsStandalone:(NSString *)content preamble:(NSString *)preamble {
    NSString *defaultPreamble = @"\\documentclass{article}\n\\usepackage[utf8]{inputenc}\n";

    if (!preamble || preamble.length == 0) {
        preamble = defaultPreamble;
    }

    return [NSString stringWithFormat:@"%@\n\\begin{document}\n%@\n\\end{document}",
                                     preamble, content];
}

- (NSArray *)extractPackages:(NSString *)texContent {
    NSMutableArray *packages = [NSMutableArray array];

    NSRegularExpression *packageRegex = [NSRegularExpression
        regularExpressionWithPattern:@"\\\\usepackage(?:\\[[^\\]]*\\])?\\{([^}]*)\\}"
                             options:0
                               error:nil];

    NSArray *matches = [packageRegex matchesInString:texContent
                                             options:0
                                               range:NSMakeRange(0, texContent.length)];

    for (NSTextCheckingResult *match in matches) {
        NSString *package = [texContent substringWithRange:[match rangeAtIndex:1]];
        [packages addObject:package];
    }

    return [packages copy];
}

- (NSArray *)extractDocumentclassOptions:(NSString *)texContent {
    NSMutableArray *options = [NSMutableArray array];

    NSRegularExpression *classRegex = [NSRegularExpression
        regularExpressionWithPattern:@"\\\\documentclass\\[([^\\]]*)\\]"
                             options:0
                               error:nil];

    NSArray *matches = [classRegex matchesInString:texContent
                                           options:0
                                             range:NSMakeRange(0, texContent.length)];

    if (matches.count > 0) {
        NSString *optionsString = [texContent substringWithRange:[matches[0] rangeAtIndex:1]];
        NSArray *optionArray = [optionsString componentsSeparatedByString:@","];

        for (NSString *option in optionArray) {
            NSString *trimmed = [option stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (trimmed.length > 0) {
                [options addObject:trimmed];
            }
        }
    }

    return [options copy];
}

@end
