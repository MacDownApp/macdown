//
//  NSString+Emoji.h
//  MacDown
//

#import <Foundation/Foundation.h>

@interface NSString (Emoji)

// Replaces ":shortcode:" with the matching emoji. HTML tags and <pre>/<code>
// blocks are left untouched.
- (NSString *)stringByReplacingEmojiShortcodes;

@end
