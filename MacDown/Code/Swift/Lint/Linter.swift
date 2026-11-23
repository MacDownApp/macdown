import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// One problem found in a document.
struct LintDiagnostic: Equatable {
    enum Severity: String { case warning, info }

    var rule: String
    var message: String
    var severity: Severity = .warning
    /// 1-based line.
    var line: Int
    /// Range in the document, in UTF-16 units (what `NSTextView` uses).
    var range: NSRange
}

/// Settings for a lint run.
struct LintOptions {
    /// Directory of the document. Used to check relative links; nil skips that rule.
    var baseDirectory: URL?
    /// Maximum line length for the `line-length` rule.
    var maxLineLength = 120
    /// Answers "does this file exist?". Replaced in tests.
    var fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
}

/// Which rules run. Rule names are stable: they appear in `config.yaml`.
enum LintRules {
    static let all = [
        "heading-increment", "no-duplicate-heading", "no-trailing-spaces",
        "list-marker-consistency", "no-broken-local-links", "no-missing-alt-text",
        "no-bare-urls", "line-length",
    ]
    /// Rules that run when the config does not name any. `line-length` is opt-in.
    static let defaults = all.filter { $0 != "line-length" }

    /// Turns the `lint.rules` config list into a set of rule names.
    /// - Names without a prefix select exactly those rules.
    /// - Names with a `-` prefix are removed (from the defaults, or from the selection).
    /// - An empty list means the default rules.
    static func resolve(_ configured: [String]) -> Set<String> {
        let positive = configured.filter { !$0.hasPrefix("-") }
        let negative = configured.filter { $0.hasPrefix("-") }.map { String($0.dropFirst()) }
        var selected = Set(positive.isEmpty ? defaults : positive)
        for name in negative { selected.remove(name) }
        return selected.intersection(all)
    }
}

/// Checks Markdown for style and link problems.
///
/// Runs on the cmark AST (for headings, links, lists) and on the lines (for
/// whitespace). It does not use the UI and is safe to run on a background queue.
/// A run is O(size of the document).
struct Linter {
    var enabled: Set<String>
    var options = LintOptions()

    init(enabledRules: Set<String> = Set(LintRules.defaults), options: LintOptions = LintOptions()) {
        enabled = enabledRules
        self.options = options
    }

    func lint(_ text: String) -> [LintDiagnostic] {
        guard !enabled.isEmpty else { return [] }
        let lines = LineIndex(text)
        var diagnostics: [LintDiagnostic] = []
        var codeLines = Set<Int>()   // 1-based lines inside code blocks.

        let needsAST = !enabled.isDisjoint(with: [
            "heading-increment", "no-duplicate-heading", "list-marker-consistency",
            "no-broken-local-links", "no-missing-alt-text", "no-bare-urls",
        ])
        let needsCodeLines = enabled.contains("no-trailing-spaces") || enabled.contains("line-length")

        if needsAST || needsCodeLines {
            walkAST(text, lines: lines, diagnostics: &diagnostics, codeLines: &codeLines)
        }
        if enabled.contains("no-trailing-spaces") { trailingSpaces(lines, codeLines, &diagnostics) }
        if enabled.contains("line-length") { lineLength(lines, codeLines, &diagnostics) }

        return diagnostics.sorted { ($0.line, $0.range.location) < ($1.line, $1.range.location) }
    }

    // MARK: AST rules

    private func walkAST(_ text: String, lines: LineIndex, diagnostics: inout [LintDiagnostic],
                         codeLines: inout Set<Int>) {
        cmark_gfm_core_extensions_ensure_registered()
        guard let parser = cmark_parser_new(CMARK_OPT_FOOTNOTES | CMARK_OPT_UNSAFE) else { return }
        defer { cmark_parser_free(parser) }
        for name in ["table", "strikethrough", "autolink", "tasklist"] {
            if let ext = cmark_find_syntax_extension(name) { cmark_parser_attach_syntax_extension(parser, ext) }
        }
        let bytes = Array(text.utf8)
        bytes.withUnsafeBufferPointer { buffer in
            buffer.baseAddress?.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
                cmark_parser_feed(parser, $0, buffer.count)
            }
        }
        guard let document = cmark_parser_finish(parser), let iterator = cmark_iter_new(document) else { return }
        defer { cmark_node_free(document); cmark_iter_free(iterator) }

        var previousHeadingLevel = 0
        var seenHeadings = Set<String>()
        var bulletStyle: UInt8?

        while true {
            let event = cmark_iter_next(iterator)
            if event == CMARK_EVENT_DONE { break }
            guard event == CMARK_EVENT_ENTER, let node = cmark_iter_get_node(iterator) else { continue }
            let type = cmark_node_get_type(node)
            let startLine = Int(cmark_node_get_start_line(node))
            let startColumn = Int(cmark_node_get_start_column(node))

            if type == CMARK_NODE_CODE_BLOCK {
                let end = Int(cmark_node_get_end_line(node))
                if startLine <= end { for l in startLine...end { codeLines.insert(l) } }
            } else if type == CMARK_NODE_HEADING, enabled.contains("heading-increment")
                        || enabled.contains("no-duplicate-heading") {
                let level = Int(cmark_node_get_heading_level(node))
                let title = headingText(node)
                let range = lines.range(line: startLine, column: startColumn, to: lines.endOfLine(startLine))
                if enabled.contains("heading-increment"), previousHeadingLevel > 0, level > previousHeadingLevel + 1 {
                    diagnostics.append(LintDiagnostic(
                        rule: "heading-increment",
                        message: "Heading level jumps from \(previousHeadingLevel) to \(level).",
                        line: startLine, range: range))
                }
                previousHeadingLevel = level
                if enabled.contains("no-duplicate-heading") {
                    let key = "\(level):" + title.lowercased()
                    if !title.isEmpty, !seenHeadings.insert(key).inserted {
                        diagnostics.append(LintDiagnostic(
                            rule: "no-duplicate-heading", message: "Duplicate heading “\(title)”.",
                            line: startLine, range: range))
                    }
                }
            } else if type == CMARK_NODE_LIST, enabled.contains("list-marker-consistency"),
                      cmark_node_get_list_type(node) == CMARK_BULLET_LIST {
                if let marker = lines.byte(line: startLine, column: startColumn),
                   marker == 0x2D || marker == 0x2A || marker == 0x2B {
                    if let first = bulletStyle, first != marker {
                        diagnostics.append(LintDiagnostic(
                            rule: "list-marker-consistency",
                            message: "List uses “\(Character(UnicodeScalar(marker)))” but earlier lists use “\(Character(UnicodeScalar(first)))”.",
                            line: startLine, range: lines.range(line: startLine, column: startColumn, length: 1)))
                    } else if bulletStyle == nil { bulletStyle = marker }
                }
            } else if type == CMARK_NODE_IMAGE {
                if enabled.contains("no-missing-alt-text"), cmark_node_first_child(node) == nil {
                    diagnostics.append(LintDiagnostic(
                        rule: "no-missing-alt-text", message: "Image has no alt text.", line: startLine,
                        range: lines.range(line: startLine, column: startColumn, to: lines.endOfLine(startLine))))
                }
                checkLocalTarget(node, startLine, startColumn, lines, &diagnostics)
            } else if type == CMARK_NODE_LINK {
                if enabled.contains("no-bare-urls"),
                   let first = lines.byte(line: startLine, column: startColumn), first != 0x5B, first != 0x3C {
                    // cmark-gfm reports the column of a bare URL one byte early, so find the text.
                    let shown = cmark_node_first_child(node).flatMap { cmark_node_get_literal($0) }
                        .map { String(cString: $0) } ?? ""
                    let column = lines.column(of: shown, line: startLine, near: startColumn) ?? startColumn
                    diagnostics.append(LintDiagnostic(
                        rule: "no-bare-urls", message: "Bare URL. Use <\(shown)> or a link.", severity: .info,
                        line: startLine, range: lines.range(line: startLine, column: column,
                                                            length: min(shown.utf8.count, 200))))
                }
                checkLocalTarget(node, startLine, startColumn, lines, &diagnostics)
            }
        }
    }

    private func headingText(_ heading: UnsafeMutablePointer<cmark_node>) -> String {
        var out = ""
        var child = cmark_node_first_child(heading)
        while let node = child {
            if let literal = cmark_node_get_literal(node) { out += String(cString: literal) }
            else if let inner = cmark_node_first_child(node), let literal = cmark_node_get_literal(inner) {
                out += String(cString: literal)
            }
            child = cmark_node_next(node)
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    private func checkLocalTarget(_ node: UnsafeMutablePointer<cmark_node>, _ line: Int, _ column: Int,
                                  _ lines: LineIndex, _ diagnostics: inout [LintDiagnostic]) {
        guard enabled.contains("no-broken-local-links"), let base = options.baseDirectory,
              let urlPointer = cmark_node_get_url(node) else { return }
        let raw = String(cString: urlPointer)
        guard let path = LinkTarget.localPath(raw) else { return }
        let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : base.appendingPathComponent(path)
        if !options.fileExists(url) {
            diagnostics.append(LintDiagnostic(
                rule: "no-broken-local-links", message: "File not found: \(path)", line: line,
                range: lines.range(line: line, column: column, to: lines.endOfLine(line))))
        }
    }

    // MARK: Line rules

    private func trailingSpaces(_ lines: LineIndex, _ codeLines: Set<Int>, _ out: inout [LintDiagnostic]) {
        for number in 1...max(lines.count, 1) where number <= lines.count && !codeLines.contains(number) {
            let bytes = lines.bytes(number)
            var end = bytes.count
            while end > 0, bytes[end - 1] == 0x20 || bytes[end - 1] == 0x09 { end -= 1 }
            let trailing = bytes.count - end
            guard trailing > 0 else { continue }
            // Exactly two spaces after text is a hard line break.
            let isHardBreak = trailing == 2 && end > 0 && number < lines.count
                && !lines.isBlank(number + 1) && bytes[end...].allSatisfy { $0 == 0x20 }
            if !isHardBreak {
                out.append(LintDiagnostic(
                    rule: "no-trailing-spaces", message: "Trailing whitespace.", severity: .info, line: number,
                    range: lines.range(line: number, column: end + 1, length: trailing)))
            }
        }
    }

    private func lineLength(_ lines: LineIndex, _ codeLines: Set<Int>, _ out: inout [LintDiagnostic]) {
        guard lines.count > 0 else { return }
        for number in 1...lines.count where !codeLines.contains(number) {
            let text = lines.text(number)
            let length = text.count
            guard length > options.maxLineLength, !text.contains("http") else { continue }
            out.append(LintDiagnostic(
                rule: "line-length", message: "Line is \(length) characters (limit \(options.maxLineLength)).",
                severity: .info, line: number,
                range: lines.range(line: number, column: 1, to: lines.endOfLine(number))))
        }
    }
}

// MARK: - Local link targets

enum LinkTarget {
    /// The file path part of a link, or nil if the link is not a local file
    /// (web link, `mailto:`, anchor, empty).
    static func localPath(_ link: String) -> String? {
        let trimmed = link.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("//") else { return nil }
        if let colon = trimmed.firstIndex(of: ":"),
           trimmed[trimmed.startIndex..<colon].allSatisfy({ $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }),
           colon != trimmed.startIndex { return nil }   // Has a scheme.
        var path = trimmed
        if let cut = path.firstIndex(where: { $0 == "#" || $0 == "?" }) { path = String(path[path.startIndex..<cut]) }
        guard !path.isEmpty else { return nil }
        return path.removingPercentEncoding ?? path
    }
}

// MARK: - Line index

/// Line start offsets over the UTF-8 bytes, with conversion to UTF-16 ranges.
struct LineIndex {
    private let text: String
    private let utf8: [UInt8]
    private let starts: [Int]   // Byte offset where each line starts.

    var count: Int { starts.count }

    init(_ text: String) {
        self.text = text
        utf8 = Array(text.utf8)
        var found = [0]
        for (i, b) in utf8.enumerated() where b == 0x0A && i + 1 <= utf8.count { found.append(i + 1) }
        // A trailing newline does not start a new line.
        if found.count > 1, found.last == utf8.count { found.removeLast() }
        starts = found
    }

    /// The bytes of a line, without the line ending. Indexed from 0.
    func bytes(_ line: Int) -> [UInt8] {
        guard line >= 1, line <= starts.count else { return [] }
        let start = starts[line - 1]
        var end = line < starts.count ? starts[line] : utf8.count
        if end > start, utf8[end - 1] == 0x0A { end -= 1 }
        if end > start, utf8[end - 1] == 0x0D { end -= 1 }
        return Array(utf8[start..<end])
    }

    func text(_ line: Int) -> String { String(decoding: bytes(line), as: UTF8.self) }
    func isBlank(_ line: Int) -> Bool { bytes(line).allSatisfy { $0 == 0x20 || $0 == 0x09 } }

    /// Byte at a 1-based (line, byte column).
    func byte(line: Int, column: Int) -> UInt8? {
        let b = bytes(line)
        return column >= 1 && column - 1 < b.count ? b[column - 1] : nil
    }

    /// 1-based byte column where `needle` starts on a line, searching from a bit before `near`.
    func column(of needle: String, line: Int, near: Int) -> Int? {
        let hay = bytes(line), pattern = Array(needle.utf8)
        guard !pattern.isEmpty, pattern.count <= hay.count else { return nil }
        var i = max(0, near - 3)
        while i + pattern.count <= hay.count {
            if hay[i] == pattern[0], Array(hay[i..<(i + pattern.count)]) == pattern { return i + 1 }
            i += 1
        }
        return nil
    }

    /// Byte column just past the end of the line text.
    func endOfLine(_ line: Int) -> Int { bytes(line).count + 1 }

    func range(line: Int, column: Int, length: Int) -> NSRange {
        range(line: line, column: column, to: column + length)
    }

    /// Range from a (line, byte column) up to a byte column on the same line.
    func range(line: Int, column: Int, to endColumn: Int) -> NSRange {
        guard line >= 1, line <= starts.count else { return NSRange(location: 0, length: 0) }
        let lineBytes = bytes(line)
        let from = max(0, min(column - 1, lineBytes.count))
        let to = max(from, min(endColumn - 1, lineBytes.count))
        let startByte = starts[line - 1] + from
        let endByte = starts[line - 1] + to
        let utf8View = text.utf8
        let lower = utf8View.index(utf8View.startIndex, offsetBy: startByte)
        let upper = utf8View.index(utf8View.startIndex, offsetBy: endByte)
        return NSRange(lower..<upper, in: text)
    }
}
