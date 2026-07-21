import Foundation

/// Security hardening for the read-only HTML preview.
///
/// The workspace-shell preview shows arbitrary `.html` files in a `WKWebView`.
/// JavaScript is already disabled at the web-view level, but that does not stop
/// a document from reaching the network via `<img src="https://…">`, remote
/// stylesheets, fonts, or CSS `url()` — any of which can leak information about
/// the viewer. `PreviewSecurity` injects a restrictive Content-Security-Policy
/// so a previewed file cannot make network requests, while still allowing the
/// document's own inline styling and embedded `data:` resources to render.
public enum PreviewSecurity {
    /// A restrictive Content-Security-Policy for the preview.
    ///
    /// `default-src 'none'` blocks every remote fetch; inline styles and
    /// `data:` images/media/fonts remain allowed so a document's own styling
    /// still renders. Nothing can reach the network.
    public static let contentSecurityPolicy =
        "default-src 'none'; img-src data:; media-src data:; font-src data:; style-src 'unsafe-inline';"

    private static var cspMetaTag: String {
        "<meta http-equiv=\"Content-Security-Policy\" content=\"\(contentSecurityPolicy)\">"
    }

    /// Returns the given HTML with a restrictive CSP `<meta>` tag injected so the
    /// preview web view cannot load remote resources.
    ///
    /// The caller's markup is preserved; only the CSP tag (and, for bare
    /// fragments, a wrapping document) is added. The CSP is placed as early as
    /// possible so it governs the whole document.
    public static func hardenedHTMLDocument(from html: String) -> String {
        // Prefer injecting into an existing <head> so full documents keep their
        // structure and their own <title>/<style> intact.
        if let headOpen = openingTagRange(of: "head", in: html) {
            var result = html
            result.insert(contentsOf: cspMetaTag, at: headOpen.upperBound)
            return result
        }
        // A document with <html> but no <head>: add a <head> holding the CSP.
        if let htmlOpen = openingTagRange(of: "html", in: html) {
            var result = html
            result.insert(contentsOf: "<head>\(cspMetaTag)</head>", at: htmlOpen.upperBound)
            return result
        }
        // A bare fragment: wrap it in a minimal hardened document.
        return "<!DOCTYPE html><html><head><meta charset=\"utf-8\">\(cspMetaTag)</head><body>\(html)</body></html>"
    }

    /// Finds the range of an opening `<name …>` tag, including the closing `>`.
    ///
    /// Matches only the exact tag name — `<head>` is matched but `<header>` is
    /// not — by requiring the character after the name to end the name (`>`,
    /// `/`, or whitespace).
    private static func openingTagRange(of name: String, in html: String) -> Range<String.Index>? {
        var searchStart = html.startIndex
        while let match = html.range(
            of: "<\(name)",
            options: .caseInsensitive,
            range: searchStart ..< html.endIndex
        ) {
            let afterName = match.upperBound
            searchStart = afterName
            guard afterName < html.endIndex, isTagNameBoundary(html[afterName]) else {
                continue
            }
            if let end = html.range(of: ">", range: afterName ..< html.endIndex) {
                return match.lowerBound ..< end.upperBound
            }
        }
        return nil
    }

    private static func isTagNameBoundary(_ character: Character) -> Bool {
        character == ">" || character == "/" || character.isWhitespace
    }
}
