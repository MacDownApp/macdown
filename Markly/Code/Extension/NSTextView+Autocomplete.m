//
//  NSTextView+Autocomplete.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 11/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "NSTextView+Autocomplete.h"
#import "NSString+Lookup.h"
#import "MPUtilities.h"


static const unichar kMPLeftSingleQuotation  = L'\u2018';
static const unichar kMPRightSingleQuotation = L'\u2019';
static const unichar kMPLeftDoubleQuotation  = L'\u201c';
static const unichar kMPRightDoubleQuotation = L'\u201d';
static const unichar kMPLeftAngleSingleQuotation  = L'\u2039';
static const unichar kMPRightAngleSingleQuotation = L'\u203a';
static const unichar kMPLeftAngleDoubleQuotation  = L'\u00ab';
static const unichar kMPRightAngleDoubleQuotation = L'\u00bb';
static const unichar kMPLeftAngleSingleBracket  = L'\u3008';
static const unichar kMPRightAngleSingleBracket = L'\u3009';
static const unichar kMPLeftAngleDoubleBracket  = L'\u300a';
static const unichar kMPRightAngleDoubleBracket = L'\u300b';

static const unichar kMPMatchingCharactersMap[][2] = {
    {L'(', L')'},
    {L'[', L']'},
    {L'{', L'}'},
    {L'<', L'>'},
    {L'\'', L'\''},
    {L'\"', L'\"'},
    {L'\uff08', L'\uff09'},     // full-width parentheses
    {L'\u300c', L'\u300d'},     // corner brackets
    {L'\u300e', L'\u300f'},     // white corner brackets
    {kMPLeftSingleQuotation, kMPRightSingleQuotation},
    {kMPLeftDoubleQuotation, kMPRightDoubleQuotation},
    {kMPLeftAngleSingleQuotation, kMPRightAngleSingleQuotation},    // Latin Single Guillemet
    {kMPLeftAngleDoubleQuotation, kMPRightAngleDoubleQuotation},    // Latin Double Guillemet
    {kMPLeftAngleSingleBracket, kMPRightAngleSingleBracket},        // East Asian Single Guillemet
    {kMPLeftAngleDoubleBracket, kMPRightAngleDoubleBracket},        // East Asian Double Guillemet
    {L'\0', L'\0'},
};

static const unichar kMPStrikethroughCharacter = L'~';

static const unichar kMPMarkupCharacters[] = {
    L'*', L'_', L'`', L'=', L'\0',
};

static NSString * const kMPListLineHeadPattern =
    @"^(\\s*)((?:(?:\\*|\\+|-|)\\s+)?)((?:\\d+\\.\\s+)?)(\\S)?";
static NSString * const kMPBlockquoteLinePattern = @"^((?:\\> ?)+).*$";


@implementation NSTextView (Autocomplete)

- (BOOL)substringInRange:(NSRange)range isSurroundedByPrefix:(NSString *)prefix
                  suffix:(NSString *)suffix
{
    NSString *content = self.string;
    NSUInteger location = range.location;
    NSUInteger length = range.length;
    if (content.length < location + length + suffix.length)
        return NO;
    if (location < prefix.length)
        return NO;

    if (![[content substringFromIndex:location + length] hasPrefix:suffix]
        || ![[content substringToIndex:location] hasSuffix:prefix])
        return NO;

    // Emphasis (*) requires special treatment because we need to eliminate
    // strong (**) but not strong-emphasis (***).
    if (![prefix isEqualToString:@"*"] || ![suffix isEqualToString:@"*"])
        return YES;
    if ([self substringInRange:range isSurroundedByPrefix:@"***" suffix:@"***"])
        return YES;
    if ([self substringInRange:range isSurroundedByPrefix:@"**" suffix:@"**"])
        return NO;
    return YES;
}


- (void)insertSpacesForTab
{
    NSString *spaces = @"    ";
    NSUInteger currentLocation = self.selectedRange.location;
    NSInteger p = [self.string locationOfFirstNewlineBefore:currentLocation];

    // Calculate how deep we need to go.
    NSUInteger offset = (currentLocation - p - 1) % 4;
    if (offset)
        spaces = [spaces substringFromIndex:offset];
    [self insertText:spaces];
}

- (BOOL)completeMatchingCharactersForTextInRange:(NSRange)range
                                      withString:(NSString *)str
                            strikethroughEnabled:(BOOL)strikethrough
{
    NSUInteger stringLength = str.length;

    // Character insert without selection.
    if (range.length == 0 && stringLength == 1)
    {
        NSUInteger location = range.location;
        if ([self completeMatchingCharacterForText:str
                                        atLocation:location])
            return YES;
    }
    // Character insert with selection (i.e. select and replace).
    else if (range.length > 0 && stringLength == 1)
    {
        unichar character = [str characterAtIndex:0];
        if ([self wrapMatchingCharactersOfCharacter:character
                                  aroundTextInRange:range
                               strikethroughEnabled:strikethrough])
            return YES;
    }
    return NO;
}

- (BOOL)completeMatchingCharacterForText:(NSString *)string
                              atLocation:(NSUInteger)location
{
    static NSCharacterSet *boundaryCharacters = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *s =
            [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
        [s formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        boundaryCharacters = [s copy];
    });
    NSString *content = self.string;
    NSUInteger contentLength = content.length;

    BOOL hasMarkedText = self.hasMarkedText;
    unichar c = [string characterAtIndex:0];
    unichar n = ' ';
    unichar p = ' ';
    if (location < contentLength)
        n = [content characterAtIndex:location];
    if (location > 0 && location <= contentLength)
        p = [content characterAtIndex:location - 1];

    for (const unichar *cs = kMPMatchingCharactersMap[0]; *cs != 0; cs += 2)
    {
        // Ignore IM input of ASCII charaters.
        if (hasMarkedText && cs[0] < L'\u0100')
            continue;

        // First part of matching characters.
        if ([boundaryCharacters characterIsMember:n] && c == cs[0]
            && ([boundaryCharacters characterIsMember:p] || cs[0] != cs[1]))
        {
            NSRange range = NSMakeRange(location, 0);
            NSString *completion = [NSString stringWithCharacters:cs length:2];
            // Mimic OS X's quote substitution if it's on.
            if (self.isAutomaticQuoteSubstitutionEnabled)
            {
                unichar c = L'\0';
                switch (cs[0])
                {
                    case L'\"':
                        c = kMPLeftDoubleQuotation;
                        break;
                    case L'\'':
                        c = kMPLeftSingleQuotation;
                        break;
                    default:
                        break;
                }
                if (c != L'\0')
                    completion = [NSString stringWithCharacters:&c length:1];
            }
            [self insertText:completion replacementRange:range];

            range.location += string.length;
            self.selectedRange = range;
            return YES;
        }
        // Second part of matching characters (shift without really inserting).
        else if (c == cs[1] && n == cs[1])
        {
            NSRange range = NSMakeRange(location + 1, 0);
            self.selectedRange = range;
            return YES;
        }
    }
    return NO;
}

- (void)wrapTextInRange:(NSRange)range withPrefix:(unichar)prefix
                 suffix:(unichar)suffix
{
    NSString *string = [self.string substringWithRange:range];
    NSString *p = [NSString stringWithCharacters:&prefix length:1];
    NSString *s = [NSString stringWithCharacters:&suffix length:1];
    NSString *wrapped = [NSString stringWithFormat:@"%@%@%@", p, string, s];
    [self insertText:wrapped replacementRange:range];

    range.location += 1;
    self.selectedRange = range;
}

- (BOOL)wrapMatchingCharactersOfCharacter:(unichar)character
                        aroundTextInRange:(NSRange)range
                     strikethroughEnabled:(BOOL)isStrikethroughEnabled
{
    for (const unichar *cs = kMPMatchingCharactersMap[0]; *cs != 0; cs += 2)
    {
        if (character == cs[0])
        {
            [self wrapTextInRange:range withPrefix:cs[0] suffix:cs[1]];
            return YES;
        }
    }
    for (size_t i = 0; kMPMarkupCharacters[i] != 0; i++)
    {
        if (character == kMPMarkupCharacters[i])
        {
            [self wrapTextInRange:range withPrefix:character suffix:character];
            return YES;
        }
    }
    if (isStrikethroughEnabled && character == kMPStrikethroughCharacter)
    {
        [self wrapTextInRange:range withPrefix:character suffix:character];
        return YES;
    }
    return NO;
}

- (BOOL)deleteMatchingCharactersAround:(NSUInteger)location
{
    NSString *string = self.string;
    if (location == 0 || location >= string.length)
        return NO;

    unichar f = [string characterAtIndex:location - 1];
    unichar b = [string characterAtIndex:location];

    for (const unichar *cs = kMPMatchingCharactersMap[0]; *cs != 0; cs += 2)
    {
        if (f == cs[0] && b == cs[1])
        {
            NSRange range = NSMakeRange(location - 1, 2);
            [self shouldChangeTextInRange:range replacementString:@""];
            [self replaceCharactersInRange:range withString:@""];
            return YES;
        }
    }
    return NO;
}

- (BOOL)unindentForSpacesBefore:(NSUInteger)location
{
    NSString *string = self.string;

    NSUInteger whitespaceCount = 0;
    while (location - whitespaceCount > 0
           && [string characterAtIndex:location - whitespaceCount - 1] == L' ')
    {
        whitespaceCount++;
        if (whitespaceCount >= 4)
            break;
    }
    if (whitespaceCount < 2)
        return NO;

    NSUInteger lineStart = [string locationOfFirstNewlineBefore:location] + 1;
    if (location <= lineStart)
        return NO;

    NSUInteger offset = (location - lineStart) % 4;
    if (offset == 0)
        offset = 4;
    if (whitespaceCount < offset)
        offset = whitespaceCount;

    NSRange range = NSMakeRange(location - offset, offset);
    [self shouldChangeTextInRange:range replacementString:@""];
    [self replaceCharactersInRange:range withString:@""];
    return YES;
}

- (BOOL)toggleForMarkupPrefix:(NSString *)prefix suffix:(NSString *)suffix
{
    NSRange range = self.selectedRange;
    NSString *selection = [self.string substringWithRange:range];
    BOOL isOn = NO;

    // Selection is already marked-up. Clear markup and maintain selection.
    NSUInteger poff = prefix.length;
    if ([self substringInRange:range isSurroundedByPrefix:prefix
                        suffix:suffix])
    {
        NSRange sub = NSMakeRange(range.location - poff,
                                  selection.length + poff + suffix.length);
        [self insertText:selection replacementRange:sub];
        range.location = sub.location;
        isOn = NO;
    }
    // Selection is normal. Mark it up and maintain selection.
    else
    {
        NSString *text = [NSString stringWithFormat:@"%@%@%@",
                          prefix, selection, suffix];
        [self insertText:text replacementRange:range];
        range.location += poff;
        isOn = YES;
    }
    self.selectedRange = range;
    return isOn;
}

- (void)toggleBlockWithPattern:(NSString *)pattern prefix:(NSString *)prefix
{
    NSRegularExpression *regex =
        [[NSRegularExpression alloc] initWithPattern:pattern options:0
                                               error:NULL];
    NSString *content = self.string;
    NSRange selectedRange = self.selectedRange;
    NSRange lineRange = [content lineRangeForRange:selectedRange];

    NSString *toProcess = [content substringWithRange:lineRange];
    BOOL hasTrailingNewline = NO;
    if ([toProcess hasSuffix:@"\n"])
    {
        toProcess = [toProcess substringToIndex:(toProcess.length - 1)];
        hasTrailingNewline = YES;
    }

    NSArray *lines = [toProcess componentsSeparatedByString:@"\n"];

    BOOL isMarked = YES;
    for (NSString *line in lines)
    {
        NSRange matchRange =
            [regex rangeOfFirstMatchInString:line options:0
                                       range:NSMakeRange(0, line.length)];
        if (matchRange.location == NSNotFound)
        {
            isMarked = NO;
            break;
        }
    }

    NSUInteger prefixLength = prefix.length;
    NSMutableArray *modLines = [NSMutableArray arrayWithCapacity:lines.count];

    __block NSUInteger totalShift = 0;
    [lines enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
        NSString *line = obj;
        if (line.length)
            totalShift += prefixLength;
        if (!isMarked)
            line = [prefix stringByAppendingString:line];
        else
            line = [line substringFromIndex:prefixLength];
        [modLines addObject:line];
    }];

    NSString *processed = [modLines componentsJoinedByString:@"\n"];
    if (hasTrailingNewline)
        processed = [NSString stringWithFormat:@"%@\n", processed];
    [self insertText:processed replacementRange:lineRange];

    if (!isMarked)
    {
        selectedRange.location += prefixLength;
        if (selectedRange.length + totalShift >= prefixLength)
            selectedRange.length += totalShift - prefixLength;
        else    // Underflow.
            selectedRange.length = 0;
    }
    else
    {
        if (prefixLength <= selectedRange.location)
            selectedRange.location -= prefixLength;
        else    // Underflow.
            selectedRange.location = 0;
        if (totalShift - prefixLength <= selectedRange.length)
            selectedRange.length -= totalShift - prefixLength;
        else    // Underflow.
            selectedRange.length = 0;

        if (selectedRange.location < lineRange.location)
        {
            selectedRange.length -= lineRange.location - selectedRange.location;
            selectedRange.location = lineRange.location;
        }
    }
    self.selectedRange = selectedRange;
}

- (void)indentSelectedLinesWithPadding:(NSString *)padding
{
    NSString *content = self.string;
    NSRange selectedRange = self.selectedRange;
    NSRange lineRange = [content lineRangeForRange:selectedRange];

    NSString *toProcess = [content substringWithRange:lineRange];
    NSArray *lines = [toProcess componentsSeparatedByString:@"\n"];
    NSMutableArray *modLines = [NSMutableArray arrayWithCapacity:lines.count];
    NSUInteger paddingLength = padding.length;

    __block NSUInteger totalShift = 0;
    [lines enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
        NSString *line = obj;
        if (line.length)
            totalShift += paddingLength;
        [modLines addObject:[padding stringByAppendingString:line]];
    }];
    if ([modLines.lastObject isEqualToString:padding])
    {
        [modLines removeLastObject];
        [modLines addObject:@""];
    }
    NSString *processed = [modLines componentsJoinedByString:@"\n"];
    [self insertText:processed replacementRange:lineRange];

    selectedRange.location += paddingLength;
    selectedRange.length +=
        (totalShift > paddingLength) ? totalShift - paddingLength : 0;
    self.selectedRange = selectedRange;
}

- (void)unindentSelectedLines
{
    NSString *content = self.string;
    NSRange selectedRange = self.selectedRange;
    NSRange lineRange = [content lineRangeForRange:selectedRange];

    // Get the lines to unindent.
    NSString *toProcess = [content substringWithRange:lineRange];
    NSArray *lines = [toProcess componentsSeparatedByString:@"\n"];

    // This will hold the modified lines.
    NSMutableArray *modLines = [NSMutableArray arrayWithCapacity:lines.count];

    // Unindent the lines one by one, and put them in the new array.
    __block NSUInteger firstShift = 0;      // Indentation of the first line.
    __block NSUInteger totalShift = 0;      // Indents removed in total.
    [lines enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
        NSString *line = obj;
        NSUInteger lineLength = line.length;
        NSUInteger shift = 0;

        for (shift = 0; shift < 4; shift++)
        {
            if (shift >= lineLength)
                break;
            unichar c = [line characterAtIndex:shift];
            if (c == '\t')
                shift++;
            if (c != ' ')
                break;
        }
        if (index == 0)
            firstShift += shift;
        totalShift += shift;
        if (shift && shift < lineLength)
            line = [line substringFromIndex:shift];
        [modLines addObject:line];
    }];

    // Join the processed lines, and replace the original with them.
    NSString *processed = [modLines componentsJoinedByString:@"\n"];
    [self insertText:processed replacementRange:lineRange];

    // Modify the selection range so that the same text (minus removed spaces)
    // are selected.
    selectedRange.location -= firstShift;
    selectedRange.length -= totalShift - firstShift;
    self.selectedRange = selectedRange;
}

- (BOOL)insertMappedContent
{
    NSString *content = self.string;
    NSUInteger contentLength = content.length;
    if (contentLength > 20)
        return NO;

    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = MPGetDataMap(@"data");
    });
    NSData *mapped = map[content];
    if (!mapped)
        return NO;
    NSArray *components = @[NSTemporaryDirectory(),
                             [NSString stringWithFormat:@"%lu", content.hash]];
    NSString *path = [NSString pathWithComponents:components];
    [mapped writeToFile:path atomically:NO];
    NSString *text = [NSString stringWithFormat:@"![%@](%@)", content, path];
    [self insertText:text replacementRange:NSMakeRange(0, contentLength)];
    self.selectedRange = NSMakeRange(2, contentLength);
    return YES;
}

- (BOOL)completeNextListItem:(BOOL)autoIncrement
{
    NSRange selectedRange = self.selectedRange;
    NSUInteger location = selectedRange.location;
    NSString *content = self.string;
    if (selectedRange.length || !content.length)
        return NO;

    NSInteger start = [content locationOfFirstNewlineBefore:location] + 1;
    NSUInteger end = location;
    NSUInteger nonwhitespace =
        [content locationOfFirstNonWhitespaceCharacterInLineBefore:location];

    // No non-whitespace character at this line.
    if (nonwhitespace == location)
        return NO;

    NSRange range = NSMakeRange(start, end - start);
    NSString *line = [self.string substringWithRange:range];

    NSRegularExpressionOptions options = NSRegularExpressionAnchorsMatchLines;
    NSRegularExpression *regex =
        [[NSRegularExpression alloc] initWithPattern:kMPListLineHeadPattern
                                             options:options
                                               error:NULL];
    NSTextCheckingResult *result =
        [regex firstMatchInString:line options:0
                            range:NSMakeRange(0, line.length)];
    if (!result || result.range.location == NSNotFound)
        return NO;

    NSString *t = nil;
    BOOL isUl = ([result rangeAtIndex:2].length != 0);
    BOOL isOl = ([result rangeAtIndex:3].length != 0);
    BOOL previousLineEmpty = ([result rangeAtIndex:4].length == 0);
    if (previousLineEmpty)
    {
        NSRange replaceRange = NSMakeRange(NSNotFound, 0);
        if (isUl)
            replaceRange = [result rangeAtIndex:2];
        else if (isOl)
            replaceRange = [result rangeAtIndex:3];
        if (replaceRange.length)
        {
            replaceRange.location += start;
            [self shouldChangeTextInRange:range replacementString:@""];
            [self replaceCharactersInRange:range withString:@""];
        }
        t = @"";
    }
    else if (isUl)
    {
        NSRange range = [result rangeAtIndex:2];
        range.length -= 1;      // Exclude trailing whitespace.
        t = [line substringWithRange:range];
    }
    else if (isOl)
    {
        NSRange range = [result rangeAtIndex:3];
        range.length -= 1;      // Exclude trailing space.
        NSString *captured = [line substringWithRange:range];
        NSInteger i = captured.integerValue;
        if (autoIncrement)
            i += 1;
        t = [NSString stringWithFormat:@"%ld.", i];
    }
    if (!t)
        return NO;

    [self insertNewline:self];
    location += 1;  // Shift for inserted newline.

    NSString *indent = [line substringWithRange:[result rangeAtIndex:1]];
    NSUInteger contentLength = content.length;

    // Has matching list item. Only insert indent.
    NSRange r = NSMakeRange(location, t.length);
    if (contentLength > location + t.length
            && [[content substringWithRange:r] isEqualToString:t])
    {
        [self insertText:indent];
        return YES;
    }

    NSString *it = [NSString stringWithFormat:@"%@%@", indent, t];

    // Has indent and matching list item. Accept it.
    r = NSMakeRange(location, it.length);
    if (contentLength > location + it.length
            && [[content substringWithRange:r] isEqualToString:it])
        return YES;

    // Insert completion for normal cases.
    if (t.length)
        it = [NSString stringWithFormat:@"%@ ", it];
    [self insertText:it];
    return YES;
}

- (BOOL)completeNextBlockquoteLine
{
    NSRange selectedRange = self.selectedRange;
    NSString *content = self.string;
    NSUInteger contentLength = content.length;
    if (selectedRange.length || !contentLength)
        return NO;

    NSRange lineRange = [content lineRangeForRange:selectedRange];
    NSString *line = [content substringWithRange:lineRange];

    NSRegularExpressionOptions options = NSRegularExpressionAnchorsMatchLines;
    NSRegularExpression *regex =
        [[NSRegularExpression alloc] initWithPattern:kMPBlockquoteLinePattern
                                             options:options error:NULL];
    NSTextCheckingResult *result =
        [regex firstMatchInString:line options:0
                            range:NSMakeRange(0, lineRange.length)];
    if (!result || result.range.location == NSNotFound)
        return NO;

    [self insertNewline:self];

    NSRange markersRange = [result rangeAtIndex:1];
    NSString *markers = [line substringWithRange:markersRange];
    NSUInteger nextLineStart = selectedRange.location + 1;

    // Has identical markers. Accept this.
    NSRange nextMarkersRange = NSMakeRange(nextLineStart, markersRange.length);
    if (contentLength > nextLineStart + markersRange.length)
    {
        NSString *nextMarkers = [content substringWithRange:nextMarkersRange];
        if ([nextMarkers isEqualToString:markers])
            return YES;
    }

    // Insert completion.
    [self insertText:markers];
    return YES;
}

- (BOOL)completeNextIndentedLine
{
    NSRange selectedRange = self.selectedRange;
    if (selectedRange.length)
        return NO;

    NSString *content = self.string;
    NSUInteger start = [content lineRangeForRange:selectedRange].location;
    NSUInteger end = [content locationOfFirstNonWhitespaceCharacterInLineBefore:
                      selectedRange.location];
    if (end <= start)
        return NO;

    [self insertNewline:self];
    NSRange indentRange = NSMakeRange(start, end - start);
    [self insertText:[content substringWithRange:indentRange]];
    return YES;
}

- (void)makeHeaderForSelectedLinesWithLevel:(NSUInteger)level
{
    NSAssert(level <= 6, @"Should be 1-6, or 0 (convert to paragraph).");
    NSString *content = self.string;
    NSRange selectedRange = self.selectedRange;
    NSRange lineRange = [content lineRangeForRange:selectedRange];

    NSString *header = [@"###### " substringFromIndex:6 - level];
    if (level == 0)
        header = [header substringToIndex:header.length - 1];
    NSUInteger headerLength = header.length;
    NSUInteger options = NSRegularExpressionDotMatchesLineSeparators;
    NSRegularExpression *regex =
        [[NSRegularExpression alloc] initWithPattern:@"^(#+ )*.*?$"
                                             options:options error:NULL];

    NSMutableArray *processedLines = [NSMutableArray array];
    NSString *toProcess = [content substringWithRange:lineRange];
    NSArray *lines = [toProcess componentsSeparatedByString:@"\n"];
    NSUInteger lineCount = lines.count;
    __block NSInteger firstShift = 0;
    __block NSInteger totalShift = 0;
    [lines enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
        NSString *line = obj;
        NSTextCheckingResult *result =
            [regex firstMatchInString:line options:0
                                range:NSMakeRange(0, line.length)];
        NSUInteger rangeCount = result.numberOfRanges;

        // Don't process empty/whitespace-only lines unless it's the only line.
        if (lineCount > 1)
        {
            NSUInteger sentinel = [line
                locationOfFirstNonWhitespaceCharacterInLineBefore:line.length];
            if (sentinel == line.length)
            {
                [processedLines addObject:line];
                return;
            }
        }

        NSString *lineContent = line;
        NSRange headerRange = NSMakeRange(0, 0);
        if (rangeCount > 1)
            headerRange = [result rangeAtIndex:1];
        if (headerRange.location != NSNotFound)
        {
            NSUInteger start = headerRange.location + headerRange.length;
            lineContent = [line substringFromIndex:start];
        }
        [processedLines addObject:[header stringByAppendingString:lineContent]];

        NSInteger shift = headerLength - headerRange.length;
        if (index == 0)
            firstShift += shift;
        totalShift += shift;
    }];
    NSString *processed = [processedLines componentsJoinedByString:@"\n"];
    [self insertText:processed replacementRange:lineRange];

    selectedRange.location += firstShift;
    selectedRange.length += totalShift - firstShift;
    self.selectedRange = selectedRange;
}

@end
