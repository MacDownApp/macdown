//
//  WebView+Shortcut.h
//  MacDown
//

#import <WebKit/WebKit.h>

@interface WebView (Shortcut)

/// Scroll view that holds the page. Removed with WebView in Phase 4.
- (NSScrollView *)enclosingScrollView;

@end
