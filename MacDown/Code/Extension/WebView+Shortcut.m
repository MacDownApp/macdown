//
//  WebView+Shortcut.m
//  MacDown
//

#import "WebView+Shortcut.h"

@implementation WebView (Shortcut)

- (NSScrollView *)enclosingScrollView
{
    return self.mainFrame.frameView.documentView.enclosingScrollView;
}

@end
