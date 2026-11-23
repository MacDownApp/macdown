//
//  MPMarkdownEngine.h
//  MacDown
//
//  The seam between MPRenderer and the code that turns Markdown text into
//  HTML. MPRenderer only talks to this protocol, so the Markdown parser can
//  be replaced without touching preview or export code.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/// Options for one render. Engine independent: each engine maps these to its
/// own parser settings. Equality is by value, so callers can detect changes.
@interface MPMarkdownRenderOptions : NSObject <NSCopying>

// Syntax extensions.
@property (nonatomic) BOOL tables;
@property (nonatomic) BOOL fencedCode;
@property (nonatomic) BOOL footnotes;
@property (nonatomic) BOOL autolink;
@property (nonatomic) BOOL strikethrough;
@property (nonatomic) BOOL underline;       // _text_ renders <u>.
@property (nonatomic) BOOL highlight;       // ==text== renders <mark>.
@property (nonatomic) BOOL quote;           // "text" renders <q>.
@property (nonatomic) BOOL superscript;     // ^text and ^(text).
@property (nonatomic) BOOL intraEmphasis;   // Emphasis inside words.
@property (nonatomic) BOOL math;            // \(..\), \[..\] and $$..$$.
@property (nonatomic) BOOL mathInlineDollar;// $..$ (needs `math`).

// HTML output.
@property (nonatomic) BOOL taskList;
@property (nonatomic) BOOL lineNumbers;     // Adds "line-numbers" to <pre>.
@property (nonatomic) BOOL hardWrap;
/// Code block info strings of the form "language:information".
@property (nonatomic) BOOL codeBlockInformation;
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

NS_ASSUME_NONNULL_END
