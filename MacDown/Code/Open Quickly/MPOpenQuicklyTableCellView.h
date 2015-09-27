//
//  MPOpenQuicklyTableCellView.h
//  MacDown
//
//  Created by Orta on 9/7/15.
//  Copyright © 2015 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MPOpenQuicklyTableCellView : NSTableCellView

/// Underlines the title
- (void)highlightTitle:(NSString *)string indexes:(NSIndexSet *)indexes;

@end
