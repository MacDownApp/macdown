//
//  MPEditorView+LineHightlight.h
//  MacDown
//
//  Created by jj on 05/06/2018.
//  Copyright © 2018 Tzu-ping Chung . All rights reserved.
//
#import "MPEditorView.h"

#ifndef MPEditorView_LineHightlight_h
#define MPEditorView_LineHightlight_h

@interface MPEditorView (LineHighlight)

/**
 * Updates the line highlight color when the theme is changed.
 */
- (void) updateLineHighlightColor;

@end

#endif /* MPEditorView_LineHightlight_h */
