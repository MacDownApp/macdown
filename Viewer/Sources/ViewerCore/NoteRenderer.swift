import Foundation
import Yams
import cmark_gfm
import cmark_gfm_extensions

/// The result of turning one note into HTML.
public struct RenderedNote {
    /// The HTML of the note (without `<html>`; see `ViewerPage`).
    public let bodyHTML: String
    public let usesMath: Bool
    public let usesMermaid: Bool
    public let usesCode: Bool
}

/// Obsidian-flavoured Markdown to HTML: CommonMark and GitHub extensions (tables, task lists,
/// strikethrough, autolinks, footnotes), math (`$..$`, `$$..$$`), `==highlight==`, callouts,
/// wikilinks, embeds, tags, comments and a collapsible properties block.
public enum NoteRenderer {
    public static func render(markdown: String, notePath: String, resolver: VaultResolving,
                              loadNote: @escaping (String) -> String?) -> RenderedNote {
        cmark_gfm_core_extensions_ensure_registered()

        let (yaml, body) = FrontMatter.split(markdown)
        let propertiesHTML = yaml.map(properties) ?? ""

        let context = ObsidianContext(resolver: resolver, note: notePath, loadNote: loadNote,
                                      depth: 0, visited: [notePath])
        let preprocessed = ObsidianPreprocessor.process(body, context: context)

        let masker = MarkdownExtensions(math: true, mathInlineDollar: true, highlight: true,
                                        superscript: false, underline: false, quote: false,
                                        noIntraWordEmphasis: false, footnotes: true)
        let masked = MarkdownExtensionMasker.mask(preprocessed, extensions: masker)

        let options = CMARK_OPT_UNSAFE | CMARK_OPT_FOOTNOTES | CMARK_OPT_TABLE_PREFER_STYLE_ATTRIBUTES
            | CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE
        var html = ""
        if let parser = cmark_parser_new(options) {
            defer { cmark_parser_free(parser) }
            for name in ["table", "strikethrough", "autolink", "tasklist"] {
                if let ext = cmark_find_syntax_extension(name) { cmark_parser_attach_syntax_extension(parser, ext) }
            }
            let bytes = Array(masked.text.utf8)
            bytes.withUnsafeBufferPointer { buffer in
                buffer.baseAddress?.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
                    cmark_parser_feed(parser, $0, buffer.count)
                }
            }
            if let document = cmark_parser_finish(parser) {
                defer { cmark_node_free(document) }
                let extensions = cmark_parser_get_syntax_extensions(parser)
                rewrite(document, options: options, extensions: extensions)
                if let out = cmark_render_html(document, options, extensions) {
                    html = String(cString: out)
                    free(out)
                }
            }
        }
        html = masked.unmask(html)
        html = propertiesHTML + html

        return RenderedNote(
            bodyHTML: html,
            usesMath: html.contains("\\(") || html.contains("\\["),
            usesMermaid: html.contains("class=\"language-mermaid\""),
            usesCode: html.range(of: "class=\"language-(?!mermaid|none)", options: .regularExpression) != nil)
    }

    // MARK: AST rewriting

    /// Headings get ids, code blocks get the markup Prism and the diagram loaders expect, and
    /// callouts replace block quotes (innermost first).
    private static func rewrite(_ document: UnsafeMutablePointer<cmark_node>, options: Int32,
                                extensions: UnsafeMutablePointer<cmark_llist>?) {
        func collect(_ types: [cmark_node_type]) -> [UnsafeMutablePointer<cmark_node>] {
            var found: [UnsafeMutablePointer<cmark_node>] = []
            guard let iterator = cmark_iter_new(document) else { return [] }
            defer { cmark_iter_free(iterator) }
            while true {
                let event = cmark_iter_next(iterator)
                if event == CMARK_EVENT_DONE { break }
                if event == CMARK_EVENT_ENTER, let node = cmark_iter_get_node(iterator), types.contains(cmark_node_get_type(node)) {
                    found.append(node)
                }
            }
            return found
        }
        func replace(_ node: UnsafeMutablePointer<cmark_node>, with html: String) {
            guard let block = cmark_node_new(CMARK_NODE_HTML_BLOCK) else { return }
            cmark_node_set_literal(block, html)
            if cmark_node_replace(node, block) != 0 { cmark_node_free(node) } else { cmark_node_free(block) }
        }

        var usedIDs: [String: Int] = [:]
        for node in collect([CMARK_NODE_HEADING, CMARK_NODE_CODE_BLOCK]) {
            if cmark_node_get_type(node) == CMARK_NODE_HEADING {
                let level = Int(cmark_node_get_heading_level(node))
                guard let out = cmark_render_html(node, options, extensions) else { continue }
                let rendered = String(cString: out)
                free(out)
                var inner = Substring(rendered)
                let open = "<h\(level)>", close = "</h\(level)>"
                if inner.hasPrefix(open) { inner = inner.dropFirst(open.count) }
                inner = Substring(inner.trimmingCharacters(in: .newlines))
                if inner.hasSuffix(close) { inner = inner.dropLast(close.count) }
                let slug = HeadingSlug.make(fromHTML: String(inner))
                let count = usedIDs[slug, default: 0]
                usedIDs[slug] = count + 1
                let id = count == 0 ? slug : "\(slug)-\(count)"
                replace(node, with: "<h\(level) id=\"\(HTMLEscape.escape(id))\">\(inner)</h\(level)>\n")
            } else {
                let info = cmark_node_get_fence_info(node).map { String(cString: $0) } ?? ""
                let code = cmark_node_get_literal(node).map { String(cString: $0) } ?? ""
                replace(node, with: CodeBlockHTML.html(info: info, code: code, lineNumbers: false,
                                                       splitInformation: false, resolveLanguage: { $0.lowercased() }))
            }
        }
        for node in collect([CMARK_NODE_BLOCK_QUOTE]).reversed() {
            guard let out = cmark_render_html(node, options, extensions) else { continue }
            let rendered = String(cString: out)
            free(out)
            if let callout = CalloutBox.html(forRenderedBlockQuote: rendered) { replace(node, with: callout) }
        }
    }

    // MARK: Properties

    private static func properties(yaml: String) -> String {
        guard let node = try? Yams.compose(yaml: yaml), case let .mapping(mapping) = node, !mapping.isEmpty else { return "" }
        func text(_ node: Node) -> String {
            switch node {
            case let .scalar(scalar): return scalar.string
            case let .sequence(items): return items.map(text).joined(separator: ", ")
            case let .mapping(map): return map.map { "\(text($0.key)): \(text($0.value))" }.joined(separator: "; ")
            case .alias: return ""
            }
        }
        let rows = mapping.map { pair in
            "<tr><th>\(HTMLEscape.escape(text(pair.key)))</th><td>\(HTMLEscape.escape(text(pair.value)))</td></tr>"
        }.joined(separator: "\n")
        return "<details class=\"properties\">\n<summary>Properties</summary>\n<table>\n\(rows)\n</table>\n</details>\n"
    }
}

/// Heading ids: lower case letters and digits, other runs become one hyphen.
enum HeadingSlug {
    static func make(fromHTML html: String) -> String {
        let text = html.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        return make(from: text)
    }

    static func make(from text: String) -> String {
        var slug = ""
        var lastWasHyphen = true
        for scalar in text.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) { slug.unicodeScalars.append(scalar); lastWasHyphen = false }
            else if !lastWasHyphen { slug.append("-"); lastWasHyphen = true }
        }
        while slug.hasSuffix("-") { slug.removeLast() }
        return slug.isEmpty ? "section" : slug
    }
}
