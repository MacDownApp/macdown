//
//  MPLayoutManager.m
//  MacDown
//
//  Created by Adam Wulf on 3/21/18.
//  Copyright © 2018 Tzu-ping Chung . All rights reserved.
//

#import "MPLayoutManager.h"

@implementation MPLayoutManager

- (void)drawGlyphsForGlyphRange:(NSRange)range atPoint:(NSPoint)point {
    NSTextStorage* storage = self.textStorage;
    NSString* string = storage.string;
    for (NSUInteger glyphIndex = range.location; glyphIndex < range.location + range.length; glyphIndex++) {
        NSUInteger characterIndex = [self characterIndexForGlyphAtIndex: glyphIndex];
        switch ([string characterAtIndex:characterIndex]) {
                
            case ' ': {
                NSFont* font = [storage attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
                [self replaceGlyphAtIndex:glyphIndex withGlyph:[font glyphWithName:@"periodcentered"]];
                break;
            }
                
            case '\t': {
                NSFont* font = [storage attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
                [self replaceGlyphAtIndex:glyphIndex withGlyph:[font glyphWithName:@"arrowright"]];
                break;
            }
                
            case '\n': {
                NSFont* font = [storage attribute:NSFontAttributeName atIndex:characterIndex effectiveRange:NULL];
                [self replaceGlyphAtIndex:glyphIndex withGlyph:[font glyphWithName:@"carriagereturn"]];
                break;
            }
                
        }
    }
    
    [super drawGlyphsForGlyphRange:range atPoint:point];
}

@end
