//
//  MPToolbarController.h
//  MacDown
//
//  Created by Niklas Berglund on 2017-02-12.
//  Copyright © 2017 Tzu-ping Chung . All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPDocument.h"

@interface MPToolbarController : NSObject<NSToolbarDelegate>

@property (weak) IBOutlet MPDocument *document;

/**
 * Update the highlight states of toolbar items that can be highlighted.
 */
- (void)updateHighlightStates;

- (void)highlightToggleEditorItem;
- (void)unhighlightToggleEditorItem;
- (void)highlightTogglePreviewItem;
- (void)unhighlightTogglePreviewItem;

@end
