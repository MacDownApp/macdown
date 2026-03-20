//
//  NSTextView+Autocomplete.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 11/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSTextView (Autocomplete)

- (BOOL)substringInRange:(NSRange)range isSurroundedByPrefix:(NSString *)prefix
                  suffix:(NSString *)suffix;
- (void)insertSpacesForTab;
- (BOOL)completeMatchingCharactersForTextInRange:(NSRange)range
                                      withString:(NSString *)str
                            strikethroughEnabled:(BOOL)strikethrough;
- (BOOL)completeMatchingCharacterForText:(NSString *)string
                              atLocation:(NSUInteger)location;
- (void)wrapTextInRange:(NSRange)range withPrefix:(unichar)prefix
                 suffix:(unichar)suffix;
- (BOOL)wrapMatchingCharactersOfCharacter:(unichar)character
                        aroundTextInRange:(NSRange)range
                     strikethroughEnabled:(BOOL)isStrikethroughEnabled;
- (BOOL)deleteMatchingCharactersAround:(NSUInteger)location;
- (BOOL)unindentForSpacesBefore:(NSUInteger)location;
- (BOOL)toggleForMarkupPrefix:(NSString *)prefix suffix:(NSString *)suffix;
- (void)toggleBlockWithPattern:(NSString *)pattern prefix:(NSString *)prefix;
- (void)indentSelectedLinesWithPadding:(NSString *)padding;
- (void)unindentSelectedLines;
- (BOOL)insertMappedContent;
- (BOOL)completeNextListItem:(BOOL)autoIncrement;
- (BOOL)completeNextBlockquoteLine;
- (BOOL)completeNextIndentedLine;
- (void)makeHeaderForSelectedLinesWithLevel:(NSUInteger)level;

@end
