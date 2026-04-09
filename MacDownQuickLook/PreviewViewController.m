#import "PreviewViewController.h"
#import <WebKit/WebKit.h>
#include "document.h"
#include "html.h"

@interface PreviewViewController () <WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, copy) void (^pendingHandler)(NSError *_Nullable);
@end

@implementation PreviewViewController

- (void)loadView
{
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    NSRect frame = NSMakeRect(0, 0, 800, 600);
    self.webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.view = self.webView;
    self.preferredContentSize = frame.size;
}

- (void)preparePreviewOfFileAtURL:(NSURL *)url
                completionHandler:(void (^)(NSError *_Nullable))handler
{
    NSError *err = nil;
    NSString *markdown = [NSString stringWithContentsOfURL:url
                                                  encoding:NSUTF8StringEncoding
                                                     error:&err];
    if (!markdown) {
        markdown = [NSString stringWithContentsOfURL:url usedEncoding:NULL error:&err];
    }
    if (!markdown) {
        handler(err);
        return;
    }

    const char *utf8 = [markdown UTF8String];
    size_t len = utf8 ? strlen(utf8) : 0;

    hoedown_buffer *ob = hoedown_buffer_new(64);
    hoedown_renderer *renderer = hoedown_html_renderer_new(0, 0);
    hoedown_extensions exts = (hoedown_extensions)(
        HOEDOWN_EXT_FENCED_CODE
        | HOEDOWN_EXT_TABLES
        | HOEDOWN_EXT_AUTOLINK
        | HOEDOWN_EXT_STRIKETHROUGH
        | HOEDOWN_EXT_SPACE_HEADERS
        | HOEDOWN_EXT_SUPERSCRIPT
        | HOEDOWN_EXT_FOOTNOTES
        | HOEDOWN_EXT_QUOTE);
    hoedown_document *doc = hoedown_document_new(renderer, exts, 16);
    hoedown_document_render(doc, ob, (const uint8_t *)utf8, len);

    NSString *body = [[NSString alloc] initWithBytes:ob->data
                                              length:ob->size
                                            encoding:NSUTF8StringEncoding] ?: @"";

    hoedown_document_free(doc);
    hoedown_html_renderer_free(renderer);
    hoedown_buffer_free(ob);

    NSString *css =
        @"html,body{margin:0;padding:0}"
        @"body{font-family:-apple-system,system-ui,sans-serif;"
        @"max-width:760px;margin:0 auto;padding:2em 1.5em;line-height:1.55;color:#222}"
        @"pre{background:#f4f4f4;padding:.6em;border-radius:4px;overflow:auto}"
        @"code{font-family:ui-monospace,Menlo,monospace;font-size:.92em}"
        @"pre code{background:transparent;padding:0}"
        @"blockquote{border-left:3px solid #ccc;padding-left:1em;color:#555;margin-left:0}"
        @"img{max-width:100%}"
        @"table{border-collapse:collapse}"
        @"td,th{border:1px solid #ddd;padding:.3em .6em}"
        @"h1,h2{border-bottom:1px solid #eee;padding-bottom:.2em}"
        @"a{color:#0366d6}"
        @"@media (prefers-color-scheme:dark){"
        @"body{background:#1e1e1e;color:#ddd}"
        @"pre{background:#2a2a2a}"
        @"blockquote{color:#aaa;border-color:#444}"
        @"h1,h2{border-color:#333}"
        @"td,th{border-color:#333}"
        @"a{color:#79b8ff}}";

    NSString *html = [NSString stringWithFormat:
        @"<!doctype html><html><head><meta charset='utf-8'>"
        @"<meta name='viewport' content='width=device-width,initial-scale=1'>"
        @"<title>%@</title><style>%@</style></head><body>%@</body></html>",
        url.lastPathComponent ?: @"", css, body];

    self.pendingHandler = handler;
    [self.webView loadHTMLString:html baseURL:nil];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    if (self.pendingHandler) {
        void (^h)(NSError *_Nullable) = self.pendingHandler;
        self.pendingHandler = nil;
        h(nil);
    }
}

- (void)webView:(WKWebView *)webView
    didFailNavigation:(WKNavigation *)navigation
            withError:(NSError *)error
{
    if (self.pendingHandler) {
        void (^h)(NSError *_Nullable) = self.pendingHandler;
        self.pendingHandler = nil;
        h(error);
    }
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                       withError:(NSError *)error
{
    if (self.pendingHandler) {
        void (^h)(NSError *_Nullable) = self.pendingHandler;
        self.pendingHandler = nil;
        h(error);
    }
}

@end
