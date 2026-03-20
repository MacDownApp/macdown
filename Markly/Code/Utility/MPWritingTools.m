//
//  MPWritingTools.m
//  Markly
//

#import "MPWritingTools.h"


#pragma mark - MPWordIssue

@implementation MPWordIssue
@end


#pragma mark - WikiLink Processor

@implementation MPWikiLinkProcessor

+ (NSString *)processWikiLinksInMarkdown:(NSString *)markdown baseURL:(NSURL *)baseURL
{
    if (!markdown.length)
        return markdown;

    static NSRegularExpression *wikiLinkRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wikiLinkRegex = [NSRegularExpression regularExpressionWithPattern:
            @"\\[\\[([^\\]|]+?)(?:\\|([^\\]]+?))?\\]\\]"
            options:0 error:nil];
    });

    NSMutableString *result = [markdown mutableCopy];
    NSArray *matches = [wikiLinkRegex matchesInString:markdown options:0
                                                range:NSMakeRange(0, markdown.length)];

    for (NSTextCheckingResult *match in [matches reverseObjectEnumerator])
    {
        NSString *target = [markdown substringWithRange:[match rangeAtIndex:1]];
        NSString *display = nil;
        if ([match rangeAtIndex:2].location != NSNotFound)
            display = [markdown substringWithRange:[match rangeAtIndex:2]];
        else
            display = target;

        NSString *filename = target;
        if (![filename.pathExtension isEqualToString:@"md"] &&
            ![filename.pathExtension isEqualToString:@"markdown"])
            filename = [filename stringByAppendingPathExtension:@"md"];

        NSString *link;
        if (baseURL)
        {
            NSURL *targetURL = [baseURL URLByAppendingPathComponent:filename];
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:targetURL.path];
            NSString *cssClass = exists ? @"wikilink" : @"wikilink wikilink-new";
            link = [NSString stringWithFormat:@"<a href=\"%@\" class=\"%@\">%@</a>",
                    filename, cssClass, display];
        }
        else
        {
            // No base URL (unsaved doc) — mark as missing
            link = [NSString stringWithFormat:@"<a href=\"%@\" class=\"wikilink wikilink-new\">%@</a>",
                    filename, display];
        }

        [result replaceCharactersInRange:match.range withString:link];
    }

    return result;
}

@end


#pragma mark - Word Categories

// Unnecessary qualifiers — words that add no meaning
static NSDictionary *MPWordCategories()
{
    static NSDictionary *categories = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Unnecessary qualifiers (yellow) — Amazon: "delete unnecessary qualifiers"
        NSSet *qualifiers = [NSSet setWithArray:@[
            @"actually", @"basically", @"certainly", @"clearly", @"definitely",
            @"effectively", @"essentially", @"extremely", @"fairly", @"frankly",
            @"honestly", @"hopefully", @"importantly", @"incredibly", @"indeed",
            @"interestingly", @"ironically", @"just", @"largely", @"literally",
            @"merely", @"mostly", @"naturally", @"notably", @"obviously",
            @"overall", @"particularly", @"personally", @"practically",
            @"presumably", @"pretty", @"primarily", @"quite", @"rather",
            @"really", @"relatively", @"seriously", @"simply", @"slightly",
            @"somewhat", @"specifically", @"strongly", @"surely", @"technically",
            @"totally", @"truly", @"typically", @"ultimately", @"undoubtedly",
            @"unfortunately", @"unnecessarily", @"utterly", @"very", @"virtually",
        ]];

        // Weasel words (orange) — Amazon: "replace weasel words with data"
        NSSet *weasels = [NSSet setWithArray:@[
            @"should", @"might", @"could", @"often", @"generally", @"usually",
            @"probably", @"significant", @"significantly", @"better", @"worse",
            @"soon", @"some", @"most", @"fewer", @"faster", @"slower",
            @"higher", @"lower", @"many", @"few", @"more", @"less",
            @"several", @"numerous", @"various", @"approximately",
            @"roughly", @"nearly", @"almost", @"around",
        ]];

        // Indirect/vague language (pink) — Amazon: "remove indirect language"
        NSSet *indirect = [NSSet setWithArray:@[
            @"believe", @"think", @"feel", @"seems", @"appears", @"perhaps",
            @"maybe", @"possibly", @"conceivably", @"arguably", @"seemingly",
            @"supposedly", @"allegedly", @"reportedly", @"apparently",
            @"stuff", @"thing", @"things", @"complex",
        ]];

        // Weak adverbs (blue) — Amazon: "remove adverbs and adjectives"
        NSSet *adverbs = [NSSet setWithArray:@[
            @"quickly", @"slowly", @"greatly", @"highly", @"deeply",
            @"vastly", @"remarkably", @"tremendously", @"immensely",
            @"exceedingly", @"enormously", @"drastically", @"substantially",
            @"considerably", @"massively", @"fundamentally", @"profoundly",
        ]];

        categories = @{
            @(MPWordIssueQualifier): qualifiers,
            @(MPWordIssueWeasel): weasels,
            @(MPWordIssueIndirect): indirect,
            @(MPWordIssueAdverb): adverbs,
        };
    });
    return categories;
}

// Flat set of ALL flagged words for HTML highlighting
static NSSet *MPAllFlaggedWords()
{
    static NSSet *all = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableSet *combined = [NSMutableSet set];
        for (NSSet *cat in [MPWordCategories() allValues])
            [combined unionSet:cat];
        all = [combined copy];
    });
    return all;
}


#pragma mark - Prose Analysis

@implementation MPProseAnalysis

+ (MPProseAnalysis *)analyzeText:(NSString *)text
{
    MPProseAnalysis *analysis = [[MPProseAnalysis alloc] init];
    NSMutableArray<MPWordIssue *> *issues = [NSMutableArray array];

    if (!text.length)
    {
        analysis.issues = issues;
        return analysis;
    }

    NSDictionary *categories = MPWordCategories();

    static NSRegularExpression *wordRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wordRegex = [NSRegularExpression regularExpressionWithPattern:@"\\b[a-zA-Z]+\\b"
                                                              options:0 error:nil];
    });

    NSArray *matches = [wordRegex matchesInString:text options:0
                                            range:NSMakeRange(0, text.length)];

    NSUInteger qualCount = 0, weaselCount = 0, indirectCount = 0, adverbCount = 0, repeatCount = 0;
    NSString *prevWord = nil;

    for (NSTextCheckingResult *match in matches)
    {
        NSRange range = match.range;
        NSString *word = [[text substringWithRange:range] lowercaseString];

        // Check each category
        BOOL found = NO;
        for (NSNumber *typeNum in categories)
        {
            NSSet *wordSet = categories[typeNum];
            if ([wordSet containsObject:word])
            {
                MPWordIssue *issue = [[MPWordIssue alloc] init];
                issue.word = word;
                issue.type = typeNum.unsignedIntegerValue;
                issue.range = range;
                [issues addObject:issue];

                switch (issue.type) {
                    case MPWordIssueQualifier: qualCount++; break;
                    case MPWordIssueWeasel: weaselCount++; break;
                    case MPWordIssueIndirect: indirectCount++; break;
                    case MPWordIssueAdverb: adverbCount++; break;
                    default: break;
                }
                found = YES;
                break; // one category per word
            }
        }

        // Repeated consecutive words
        if (prevWord && [prevWord isEqualToString:word] && word.length > 1)
        {
            MPWordIssue *issue = [[MPWordIssue alloc] init];
            issue.word = word;
            issue.type = MPWordIssueRepeated;
            issue.range = range;
            [issues addObject:issue];
            repeatCount++;
        }

        prevWord = word;
    }

    analysis.issues = issues;
    analysis.qualifierCount = qualCount;
    analysis.weaselCount = weaselCount;
    analysis.indirectCount = indirectCount;
    analysis.adverbCount = adverbCount;
    analysis.repeatedCount = repeatCount;
    return analysis;
}

@end


#pragma mark - Filler Highlighter for HTML

@implementation MPFillerHighlighter

+ (NSString *)highlightFillersInHTML:(NSString *)html
{
    if (!html.length)
        return html;

    NSSet *allWords = MPAllFlaggedWords();
    NSDictionary *categories = MPWordCategories();

    // Build per-category regexes with different CSS classes
    // For HTML we use a combined regex and assign class based on lookup
    NSString *pattern = [NSString stringWithFormat:@"\\b(%@)\\b",
        [[allWords allObjects] componentsJoinedByString:@"|"]];

    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:pattern
                             options:NSRegularExpressionCaseInsensitive
                               error:nil];

    NSMutableString *result = [NSMutableString string];
    NSRegularExpression *tagRegex = [NSRegularExpression
        regularExpressionWithPattern:@"(<[^>]*>)"
                             options:0 error:nil];

    NSArray *tagMatches = [tagRegex matchesInString:html options:0
                                              range:NSMakeRange(0, html.length)];

    NSUInteger lastEnd = 0;
    BOOL insideCode = NO;

    for (NSTextCheckingResult *tagMatch in tagMatches)
    {
        if (tagMatch.range.location > lastEnd)
        {
            NSRange textRange = NSMakeRange(lastEnd, tagMatch.range.location - lastEnd);
            NSString *textPart = [html substringWithRange:textRange];

            if (!insideCode)
            {
                // Replace each match with colored mark based on category
                NSMutableString *highlighted = [textPart mutableCopy];
                NSArray *wordMatches = [regex matchesInString:textPart options:0
                                                        range:NSMakeRange(0, textPart.length)];
                for (NSTextCheckingResult *wm in [wordMatches reverseObjectEnumerator])
                {
                    NSString *word = [[textPart substringWithRange:wm.range] lowercaseString];
                    NSString *cssClass = @"weasel-qual"; // default
                    for (NSNumber *typeNum in categories)
                    {
                        if ([categories[typeNum] containsObject:word])
                        {
                            switch (typeNum.unsignedIntegerValue) {
                                case MPWordIssueQualifier: cssClass = @"weasel-qual"; break;
                                case MPWordIssueWeasel: cssClass = @"weasel-weasel"; break;
                                case MPWordIssueIndirect: cssClass = @"weasel-indirect"; break;
                                case MPWordIssueAdverb: cssClass = @"weasel-adverb"; break;
                                default: break;
                            }
                            break;
                        }
                    }
                    NSString *original = [textPart substringWithRange:wm.range];
                    NSString *replacement = [NSString stringWithFormat:
                        @"<mark class=\"%@\">%@</mark>", cssClass, original];
                    [highlighted replaceCharactersInRange:wm.range withString:replacement];
                }
                [result appendString:highlighted];
            }
            else
            {
                [result appendString:textPart];
            }
        }

        NSString *tag = [html substringWithRange:tagMatch.range];
        [result appendString:tag];

        NSString *tagLower = tag.lowercaseString;
        if ([tagLower hasPrefix:@"<code"] || [tagLower hasPrefix:@"<pre"])
            insideCode = YES;
        else if ([tagLower hasPrefix:@"</code"] || [tagLower hasPrefix:@"</pre"])
            insideCode = NO;

        lastEnd = NSMaxRange(tagMatch.range);
    }

    if (lastEnd < html.length)
    {
        NSString *textPart = [html substringFromIndex:lastEnd];
        if (!insideCode)
        {
            NSMutableString *highlighted = [textPart mutableCopy];
            NSArray *wordMatches = [regex matchesInString:textPart options:0
                                                    range:NSMakeRange(0, textPart.length)];
            for (NSTextCheckingResult *wm in [wordMatches reverseObjectEnumerator])
            {
                NSString *original = [textPart substringWithRange:wm.range];
                [highlighted replaceCharactersInRange:wm.range
                    withString:[NSString stringWithFormat:@"<mark class=\"weasel-qual\">%@</mark>", original]];
            }
            [result appendString:highlighted];
        }
        else
        {
            [result appendString:textPart];
        }
    }

    return result;
}

@end
