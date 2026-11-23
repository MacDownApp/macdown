//
//  MPMarkdownEngine.h
//  MacDown
//
//  The seam between MPRenderer and the code that turns Markdown text into
//  HTML. MPRenderer only talks to this protocol, so the Markdown parser can
//  be replaced without touching preview or export code.
//

#import <Foundation/Foundation.h>


/// Options for one render. `extensions` and `rendererFlags` currently carry
/// Hoedown flag values (see MPPreferences+Hoedown.h).
@interface MPMarkdownRenderOptions : NSObject

@property (nonatomic) int extensions;
@property (nonatomic) int rendererFlags;
@property (nonatomic) BOOL smartyPants;
@property (nonatomic) BOOL rendersTOC;
@property (nonatomic) BOOL detectsFrontMatter;

@end


@interface MPMarkdownResult : NSObject

/// HTML for the body of the page (no <html> wrapper).
@property (nonatomic, copy, readonly) NSString *html;
/// Languages used by fenced code blocks, in script load order (dependencies
/// first). Used to pick the Prism components the page needs.
@property (nonatomic, copy, readonly) NSArray<NSString *> *languages;

- (instancetype)initWithHTML:(NSString *)html
                   languages:(NSArray<NSString *> *)languages;

@end


@protocol MPMarkdownEngine <NSObject>

/// Converts Markdown to body HTML. Safe to call from a background queue.
/// Must not keep state between calls.
- (MPMarkdownResult *)renderMarkdown:(NSString *)markdown
                             options:(MPMarkdownRenderOptions *)options;

@end
