import Foundation

/// Obsidian callouts: a block quote whose first line is `[!type]`, `[!type] Title`,
/// `[!type]- Title` (folded) or `[!type]+ Title` (open, foldable).
enum CalloutBox {
    private static let aliases: [String: String] = [
        "summary": "abstract", "tldr": "abstract", "hint": "tip", "important": "tip",
        "check": "success", "done": "success", "help": "question", "faq": "question",
        "caution": "warning", "attention": "warning", "fail": "failure", "missing": "failure",
        "error": "danger", "cite": "quote",
    ]
    private static let icons: [String: String] = [
        "note": "✎", "abstract": "☰", "info": "ⓘ", "todo": "☑", "tip": "✦", "success": "✓",
        "question": "?", "warning": "⚠", "failure": "✕", "danger": "⚡", "bug": "✱", "example": "☷", "quote": "❝",
    ]

    private static let marker = try! NSRegularExpression(
        pattern: "^<blockquote>\\n<p>\\[!([A-Za-z0-9_-]+)\\]([+-]?)[ \\t]*", options: [])

    /// Returns the callout markup for the rendered HTML of a block quote, or nil if it is not a callout.
    static func html(forRenderedBlockQuote html: String) -> String? {
        let range = NSRange(html.startIndex..., in: html)
        guard let match = marker.firstMatch(in: html, options: [], range: range),
              let typeRange = Range(match.range(at: 1), in: html),
              let foldRange = Range(match.range(at: 2), in: html),
              let all = Range(match.range, in: html),
              html.hasSuffix("</blockquote>\n") else { return nil }

        let rawType = html[typeRange].lowercased()
        let kind = aliases[rawType] ?? rawType
        let fold = String(html[foldRange])
        var rest = String(html[all.upperBound...].dropLast("</blockquote>\n".count))

        // The title runs to the end of the first line.
        var title = ""
        if let newline = rest.range(of: "\n"), rest[rest.startIndex..<newline.lowerBound].range(of: "</p>") == nil {
            title = String(rest[rest.startIndex..<newline.lowerBound])
            rest = "<p>" + rest[newline.upperBound...]
        } else if let close = rest.range(of: "</p>") {
            title = String(rest[rest.startIndex..<close.lowerBound])
            rest = String(rest[close.upperBound...])
        }
        title = title.trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix("<p></p>") { rest.removeFirst("<p></p>".count) }
        if title.isEmpty { title = rawType.prefix(1).uppercased() + rawType.dropFirst() }
        let icon = icons[kind] ?? icons["note"]!
        let head = "<span class=\"callout-icon\">\(icon)</span><span class=\"callout-title-text\">\(title)</span>"
        let content = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeKind = kind.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }

        if fold.isEmpty {
            return "<div class=\"callout\" data-callout=\"\(safeKind)\">\n<div class=\"callout-title\">\(head)</div>\n"
                + (content.isEmpty ? "" : "<div class=\"callout-content\">\n\(content)\n</div>\n") + "</div>\n"
        }
        return "<details class=\"callout\" data-callout=\"\(safeKind)\"\(fold == "+" ? " open" : "")>\n<summary class=\"callout-title\">\(head)</summary>\n"
            + "<div class=\"callout-content\">\n\(content)\n</div>\n</details>\n"
    }
}
