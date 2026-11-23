import Foundation

/// Turns a theme variant into the CSS that styles the preview.
///
/// The output is plain CSS that comes after the base stylesheet. Selectors start
/// with `body` so they win over the base style without `!important`.
/// Every value comes from a validated hex color or a number, so no theme file can
/// put arbitrary text into the CSS.
enum ThemeCSS {
    /// Prism token classes for each theme token.
    private static let tokenSelectors: [(token: String, selectors: [String])] = [
        ("comment", [".token.comment", ".token.prolog", ".token.doctype", ".token.cdata"]),
        ("keyword", [".token.keyword", ".token.atrule", ".token.selector", ".token.important"]),
        ("string", [".token.string", ".token.attr-value", ".token.char", ".token.regex", ".token.template-string"]),
        ("number", [".token.number", ".token.boolean", ".token.constant", ".token.symbol", ".token.unit"]),
        ("function", [".token.function", ".token.method"]),
        ("type", [".token.class-name", ".token.builtin", ".token.namespace", ".token.tag"]),
    ]

    static func css(for variant: ThemeVariant, isDark: Bool) -> String {
        var out = "/* Generated from the MacDown theme. Do not edit. */\n"
        let bg = variant.preview.background.cssString, text = variant.preview.text.cssString
        out += "html { color-scheme: \(isDark ? "dark" : "light"); background: \(bg); }\n"
        out += "body { background: \(bg); color: \(text);"
        if let width = variant.preview.contentWidth {
            out += " max-width: \(width)px; margin-left: auto; margin-right: auto;"
        }
        out += " }\n"

        let tokens = variant.tokens
        func rule(_ selector: String, _ token: String, background: Bool = false) {
            guard let style = tokens[token] else { return }
            var declarations = ""
            if let color = style.color { declarations += "color: \(color.cssString); " }
            if style.bold { declarations += "font-weight: bold; " }
            if style.italic { declarations += "font-style: italic; " }
            if !declarations.isEmpty { out += "\(selector) { \(declarations.trimmingCharacters(in: .whitespaces)) }\n" }
        }

        rule("body h1, body h2, body h3, body h4, body h5, body h6", "heading")
        rule("body a", "link")
        rule("body em", "emphasis")
        rule("body strong", "strong")
        rule("body :not(pre) > code", "code")
        rule("body blockquote", "quote")
        if let quote = tokens["quote"]?.color {
            out += "body blockquote { border-left-color: \(quote.cssString); }\n"
            out += "body hr { border-color: \(quote.cssString); background-color: \(quote.cssString); }\n"
        }
        if let list = tokens["list"]?.color { out += "body li::marker { color: \(list.cssString); }\n" }

        // Code blocks sit on a slightly different background than the page.
        let codeBackground = variant.editor.lineHighlight ?? variant.editor.text.withAlpha(0.06)
        out += "body pre, body pre code { background: \(codeBackground.cssString); color: \(text); text-shadow: none; }\n"
        out += "body table th, body table td { border-color: \(variant.editor.text.withAlpha(0.2).cssString); }\n"

        for (token, selectors) in tokenSelectors {
            rule(selectors.map { "body " + $0 }.joined(separator: ", "), token)
        }
        out += "body .token.operator, body .token.punctuation { color: \(text); background: none; }\n"
        return out
    }
}
