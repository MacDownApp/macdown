//
//  MPPreferences+Markdown.h
//  MacDown
//

#import "MPPreferences.h"
#import "MPMarkdownEngine.h"

@interface MPPreferences (Markdown)

/// The Markdown engine options that these preferences describe.
- (MPMarkdownRenderOptions *)markdownRenderOptions;

@end
