//
//  MPOpenQuicklyTableCellView.m
//  MacDown
//
//  Created by Orta on 9/7/15.
//  Copyright © 2015 Tzu-ping Chung . All rights reserved.
//

#import "MPOpenQuicklyTableCellView.h"

@implementation MPOpenQuicklyTableCellView

- (void)highlightTitle:(NSString *)string indexes:(NSIndexSet *)indexes
{
    self.textField.attributedStringValue = [self underlinedAttributedStringWithString:string  withIndexSet:indexes];
}

- (NSAttributedString *)underlinedAttributedStringWithString:(NSString*)inString withIndexSet:(NSIndexSet *)indexes
{
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString:inString];

    [attrString beginEditing];
    [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {

        [attrString addAttribute:
         NSUnderlineStyleAttributeName value:@(NSSingleUnderlineStyle) range:NSMakeRange(idx, 1)];
    }];
    [attrString endEditing];

    return attrString;
}

@end
