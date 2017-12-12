//
//  NSString+Lookup.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 11/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "NSString+Lookup.h"
#import "YAMLSerialization.h"
#import "MPUtilities.h"


@implementation NSString (Lookup)

- (NSInteger)locationOfFirstNewlineBefore:(NSUInteger)location
{
    if (location > self.length)
        location = self.length;
    NSUInteger start;
    [self getLineStart:&start end:NULL contentsEnd:NULL
              forRange:NSMakeRange(location, 0)];
    return start - 1;
}

- (NSUInteger)locationOfFirstNewlineAfter:(NSUInteger)location
{
    location++;
    if (location > self.length)
        location = self.length;
    NSUInteger end;
    [self getLineStart:NULL end:NULL contentsEnd:&end
              forRange:NSMakeRange(location, 0)];
    return end;
}

- (NSUInteger)locationOfFirstNonWhitespaceCharacterInLineBefore:(NSUInteger)loc
{
    NSInteger p = [self locationOfFirstNewlineBefore:loc] + 1;
    NSUInteger length = self.length;
    if (loc > length)
        loc = length;
    while (p < loc && MPCharacterIsWhitespace([self characterAtIndex:p]))
        p++;
    return p;
}

- (NSArray *)matchesForPattern:(NSString *)p
{
    NSRegularExpression *e =
        [[NSRegularExpression alloc] initWithPattern:p options:0 error:NULL];
    return [e matchesInString:self options:0 range:NSMakeRange(0, self.length)];
}

- (id)frontMatter:(NSUInteger *)contentOffset
{
    static NSString *pattern =
        @"^-{3}[\r\n]+(.*?[\r\n]+)((?:-{3})|(?:\\.{3}))";
    NSRegularExpressionOptions op = NSRegularExpressionDotMatchesLineSeparators;
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:pattern
                                                  options:op error:NULL];
    NSTextCheckingResult *result =
        [regex firstMatchInString:self options:0
                            range:NSMakeRange(0, self.length)];
    if (!result)    // No front matter match. Do nothing.
    {
        if (contentOffset)
            *contentOffset = 0;
        return nil;
    }

    NSString *frontMatter = [self substringWithRange:[result rangeAtIndex:1]];
    NSArray *objects =
        [YAMLSerialization objectsWithYAMLString:frontMatter
                                         options:kYAMLReadOptionStringScalars
                                           error:NULL];
    if (!objects.count)
    {
        if (contentOffset)
            *contentOffset = 0;
        return nil;
    }
    if (contentOffset)
        *contentOffset = [result rangeAtIndex:0].length;
    return objects[0];
}

- (NSString *)titleString
{
    NSString *pattern = @"\\s+(\\S.*)$";

    // Try to find the highest ranked title.
    for (NSUInteger i = 0; i < 6; i++)
    {
        pattern = [@"#" stringByAppendingString:pattern];
        NSString *p = [NSString stringWithFormat:@"%@%@", @"^", pattern];
        NSRegularExpressionOptions opt = NSRegularExpressionAnchorsMatchLines;
        NSRegularExpression *regex =
            [[NSRegularExpression alloc] initWithPattern:p options:opt
                                                   error:NULL];
        NSTextCheckingResult *result =
            [regex firstMatchInString:self options:0
                                range:NSMakeRange(0, self.length)];
        if (result)
        {
            NSString *title = [self substringWithRange:[result rangeAtIndex:1]];
            return title;
        }
    }
    return nil;
}

- (BOOL)hasExtension:(NSString *)extension
{
    return [self.pathExtension isEqualToString:extension];
}

@end
