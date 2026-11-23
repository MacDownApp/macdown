import Foundation
import os
import cmark_gfm
import cmark_gfm_extensions

/// Markdown engine built on cmark-gfm (CommonMark with GitHub extensions).
///
/// Pipeline:
/// 1. Front matter (YAML) is cut off and turned into an HTML table.
/// 2. MacDown's extra syntax (math, highlight, superscript, underline, quote)
///    is replaced by placeholders (`MarkdownExtensionMasker`).
/// 3. cmark parses and builds the AST. Headings and code blocks are rewritten
///    in the AST, so they keep the markup that MacDown's styles and Prism need.
/// 4. cmark renders HTML; the table of contents, task list markup and
///    placeholders are filled in.
@objc(MPCMarkEngine)
final class CMarkEngine: NSObject, MPMarkdownEngine {
    private static let registerExtensions: Void = { cmark_gfm_core_extensions_ensure_registered() }()
    private static let signposter = OSSignposter(subsystem: "app.macdown", category: "markdown")

    private static let tocRegex = try! NSRegularExpression(
        pattern: "<p.*?>\\s*\\[TOC\\]\\s*</p>", options: [.caseInsensitive])
    // cmark renders `<li><input type="checkbox" checked="" disabled="" /> text`.
    private static let taskRegex = try! NSRegularExpression(
        pattern: "<li>(\\s*(?:<p>)?)<input type=\"checkbox\"( checked=\"\")? disabled=\"\" />",
        options: [])

    // Loose list: cmark puts the checkbox before the paragraph. Move it inside,
    // so the box stays on the same line as the text.
    private static let looseTaskRegex = try! NSRegularExpression(
        pattern: "(<li class=\"task-list-item\">)<input type=\"checkbox\"( checked)?>\\s*\n<p>",
        options: [])

    func renderMarkdown(_ markdown: String, options: MPMarkdownRenderOptions) -> MPMarkdownResult {
        _ = CMarkEngine.registerExtensions
        let signposter = CMarkEngine.signposter
        let state = signposter.beginInterval("render")
        defer { signposter.endInterval("render", state) }

        // 1. Front matter.
        var body = markdown
        var frontMatterHTML: String?
        if options.detectsFrontMatter {
            var offset: UInt = 0
            let nsText = markdown as NSString
            if let frontMatter = nsText.frontMatter(&offset) {
                frontMatterHTML = (frontMatter as? NSObject)?.htmlTable()
            }
            body = nsText.substring(from: Int(offset))
        }

        // 2. Extension syntax.
        let extensions = MarkdownExtensions(
            math: options.math, mathInlineDollar: options.mathInlineDollar,
            highlight: options.highlight, superscript: options.superscript,
            underline: options.underline, quote: options.quote,
            noIntraWordEmphasis: !options.intraEmphasis, footnotes: options.footnotes)
        let masked = MarkdownExtensionMasker.mask(body, extensions: extensions)

        // 3. Parse.
        var cmarkOptions = CMARK_OPT_UNSAFE | CMARK_OPT_TABLE_PREFER_STYLE_ATTRIBUTES
            | CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE
        if options.footnotes { cmarkOptions |= CMARK_OPT_FOOTNOTES }
        if options.smartyPants { cmarkOptions |= CMARK_OPT_SMART }
        if options.hardWrap { cmarkOptions |= CMARK_OPT_HARDBREAKS }

        guard let parser = cmark_parser_new(cmarkOptions) else {
            return MPMarkdownResult(html: "", languages: [])
        }
        defer { cmark_parser_free(parser) }

        var extensionNames: [String] = []
        if options.tables { extensionNames.append("table") }
        if options.strikethrough { extensionNames.append("strikethrough") }
        if options.autolink { extensionNames.append("autolink") }
        if options.taskList { extensionNames.append("tasklist") }
        for name in extensionNames {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }

        let bytes = Array(masked.text.utf8)
        bytes.withUnsafeBufferPointer { buffer in
            buffer.baseAddress?.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
                cmark_parser_feed(parser, $0, buffer.count)
            }
        }
        guard let document = cmark_parser_finish(parser) else {
            return MPMarkdownResult(html: "", languages: [])
        }
        defer { cmark_node_free(document) }
        let syntaxExtensions = cmark_parser_get_syntax_extensions(parser)

        // 3b. Rewrite headings and code blocks.
        var languages: [String] = []
        let tocEntries = CMarkEngine.rewriteBlocks(
            in: document, options: options, renderOptions: cmarkOptions,
            extensions: syntaxExtensions, languages: &languages)

        // 4. Render and fill in.
        var html = ""
        if let out = cmark_render_html(document, cmarkOptions, syntaxExtensions) {
            html = String(cString: out)
            free(out)
        }

        if options.rendersTOC {
            let toc = TableOfContents.html(for: tocEntries)
            let range = NSRange(html.startIndex..., in: html)
            html = CMarkEngine.tocRegex.stringByReplacingMatches(
                in: html, options: [], range: range,
                withTemplate: NSRegularExpression.escapedTemplate(for: toc))
        }
        if options.taskList {
            let range = NSRange(html.startIndex..., in: html)
            html = CMarkEngine.taskRegex.stringByReplacingMatches(
                in: html, options: [], range: range,
                withTemplate: "<li class=\"task-list-item\">$1<input type=\"checkbox\"$2>")
                .replacingOccurrences(of: "checkbox\" checked=\"\">", with: "checkbox\" checked>")
            let again = NSRange(html.startIndex..., in: html)
            html = CMarkEngine.looseTaskRegex.stringByReplacingMatches(
                in: html, options: [], range: again,
                withTemplate: "$1<p><input type=\"checkbox\"$2> ")
        }
        html = masked.unmask(html)
        if let frontMatterHTML = frontMatterHTML {
            html = frontMatterHTML + "\n" + html
        }
        return MPMarkdownResult(html: html, languages: languages)
    }

    // MARK: AST rewriting

    private static func rewriteBlocks(
        in document: UnsafeMutablePointer<cmark_node>, options: MPMarkdownRenderOptions,
        renderOptions: Int32, extensions: UnsafeMutablePointer<cmark_llist>?,
        languages: inout [String]
    ) -> [TableOfContents.Entry] {
        var targets: [UnsafeMutablePointer<cmark_node>] = []
        if let iterator = cmark_iter_new(document) {
            defer { cmark_iter_free(iterator) }
            while true {
                let event = cmark_iter_next(iterator)
                if event == CMARK_EVENT_DONE { break }
                guard event == CMARK_EVENT_ENTER, let node = cmark_iter_get_node(iterator) else { continue }
                let type = cmark_node_get_type(node)
                if type == CMARK_NODE_HEADING || type == CMARK_NODE_CODE_BLOCK { targets.append(node) }
            }
        }

        var entries: [TableOfContents.Entry] = []
        var headingIndex = 0
        for node in targets {
            let replacement: String
            if cmark_node_get_type(node) == CMARK_NODE_HEADING {
                let level = Int(cmark_node_get_heading_level(node))
                guard let out = cmark_render_html(node, renderOptions, extensions) else { continue }
                let rendered = String(cString: out)
                free(out)
                // "<hN>inner</hN>\n" -> inner.
                let open = "<h\(level)>", close = "</h\(level)>"
                var inner = Substring(rendered)
                if inner.hasPrefix(open) { inner = inner.dropFirst(open.count) }
                inner = Substring(inner.trimmingCharacters(in: .newlines))
                if inner.hasSuffix(close) { inner = inner.dropLast(close.count) }
                entries.append(TableOfContents.Entry(level: level, html: String(inner), index: headingIndex))
                replacement = "<h\(level) id=\"toc_\(headingIndex)\">\(inner)</h\(level)>\n"
                headingIndex += 1
            } else {
                let info = cmark_node_get_fence_info(node).map { String(cString: $0) } ?? ""
                let code = cmark_node_get_literal(node).map { String(cString: $0) } ?? ""
                replacement = CodeBlockHTML.html(
                    info: info, code: code, lineNumbers: options.lineNumbers,
                    splitInformation: options.codeBlockInformation,
                    resolveLanguage: { PrismLanguages.shared.resolve($0, into: &languages) })
            }
            replace(node, withHTML: replacement)
        }

        // Alerts ("> [!NOTE]") are block quotes. They are handled after the
        // headings and code blocks inside them were rewritten, innermost first.
        var quotes: [UnsafeMutablePointer<cmark_node>] = []
        if let iterator = cmark_iter_new(document) {
            defer { cmark_iter_free(iterator) }
            while true {
                let event = cmark_iter_next(iterator)
                if event == CMARK_EVENT_DONE { break }
                if event == CMARK_EVENT_ENTER, let node = cmark_iter_get_node(iterator),
                   cmark_node_get_type(node) == CMARK_NODE_BLOCK_QUOTE { quotes.append(node) }
            }
        }
        for node in quotes.reversed() {
            guard let out = cmark_render_html(node, renderOptions, extensions) else { continue }
            let rendered = String(cString: out)
            free(out)
            if let alert = AlertBox.html(forRenderedBlockQuote: rendered) {
                replace(node, withHTML: alert)
            }
        }
        return entries
    }

    private static func replace(_ node: UnsafeMutablePointer<cmark_node>, withHTML html: String) {
        guard let block = cmark_node_new(CMARK_NODE_HTML_BLOCK) else { return }
        cmark_node_set_literal(block, html)
        if cmark_node_replace(node, block) != 0 { cmark_node_free(node) } else { cmark_node_free(block) }
    }
}
