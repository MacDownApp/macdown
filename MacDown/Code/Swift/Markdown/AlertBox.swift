import Foundation

/// GitHub style alerts: a block quote whose first line is `[!NOTE]`, `[!TIP]`,
/// `[!IMPORTANT]`, `[!WARNING]` or `[!CAUTION]`.
///
/// Output:
/// ```html
/// <div class="markdown-alert markdown-alert-note">
/// <p class="markdown-alert-title">Note</p>
/// <p>Text</p>
/// </div>
/// ```
enum AlertBox {
    private static let types = ["NOTE": "Note", "TIP": "Tip", "IMPORTANT": "Important",
                                "WARNING": "Warning", "CAUTION": "Caution"]

    private static let marker = try! NSRegularExpression(
        pattern: "^<blockquote>\\n<p>\\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\\][ \\t]*(?:<br />)?\\n?",
        options: [.caseInsensitive])

    /// Returns the alert markup for the rendered HTML of a block quote, or nil
    /// if the quote is not an alert.
    static func html(forRenderedBlockQuote html: String) -> String? {
        let range = NSRange(html.startIndex..., in: html)
        guard let match = marker.firstMatch(in: html, options: [], range: range),
              let typeRange = Range(match.range(at: 1), in: html),
              let title = types[html[typeRange].uppercased()],
              let markerRange = Range(match.range, in: html)
        else { return nil }

        let kind = html[typeRange].lowercased()
        var rest = String(html[markerRange.upperBound...])
        // Close the quote with a div. The first paragraph may now be empty.
        guard rest.hasSuffix("</blockquote>\n") else { return nil }
        rest.removeLast("</blockquote>\n".count)
        if rest.hasPrefix("</p>") { rest.removeFirst("</p>".count) } else { rest = "<p>" + rest }
        return "<div class=\"markdown-alert markdown-alert-\(kind)\">\n"
            + "<p class=\"markdown-alert-title\">\(title)</p>\n"
            + rest.trimmingCharacters(in: .newlines) + "\n</div>\n"
    }
}
