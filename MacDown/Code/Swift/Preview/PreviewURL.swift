import Foundation

/// URLs and HTML rewriting for the preview.
///
/// `WKWebView` does not let a page loaded from a string read `file://`
/// resources (local images, the bundled style and scripts). The preview
/// therefore uses its own scheme, `macdown-file`, which has the same paths as
/// `file` but is served by `PreviewSchemeHandler`.
enum PreviewURL {
    static let scheme = "macdown-file"

    /// The preview URL for a file URL: same path, other scheme.
    static func previewURL(for file: URL) -> URL {
        guard var parts = URLComponents(url: file, resolvingAgainstBaseURL: false) else { return file }
        parts.scheme = scheme
        return parts.url ?? file
    }

    /// The preview base URL for a document. A folder gets a trailing slash, so that
    /// relative links resolve inside it and not next to it.
    static func baseURL(for file: URL) -> URL {
        var isDirectory: ObjCBool = false
        if file.isFileURL, !file.hasDirectoryPath,
           FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return previewURL(for: URL(fileURLWithPath: file.path, isDirectory: true))
        }
        return previewURL(for: file)
    }

    /// The file URL for a preview URL. Other URLs (https, mailto, ...) are returned unchanged.
    static func fileURL(for url: URL) -> URL {
        guard url.scheme == scheme, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        parts.scheme = "file"
        return parts.url ?? url
    }

    private static let fileReference = try! NSRegularExpression(
        pattern: "(src|href|poster|data)(\\s*=\\s*)([\"'])file://", options: [.caseInsensitive])

    private static let mathJaxCDN = "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.3/MathJax.js"

    /// Rewrites the page so every local resource goes through the preview scheme.
    /// - `src="file://..."` and `href="file://..."` get the preview scheme.
    /// - The MathJax CDN address becomes the copy inside the app, so math works offline.
    /// Text outside attributes (for example a code block that shows a file path) is not touched.
    static func rewrite(html: String, localMathJax: URL? = Bundle.main.url(forResource: "MathJax", withExtension: "js", subdirectory: "MathJax")) -> String {
        var result = html
        if let local = localMathJax, result.contains(mathJaxCDN) {
            result = result.replacingOccurrences(of: mathJaxCDN, with: previewURL(for: local).absoluteString)
        }
        guard result.range(of: "file://", options: .caseInsensitive) != nil else { return result }
        let range = NSRange(result.startIndex..., in: result)
        return fileReference.stringByReplacingMatches(in: result, options: [], range: range,
                                                      withTemplate: "$1$2$3\(scheme)://")
    }
}
