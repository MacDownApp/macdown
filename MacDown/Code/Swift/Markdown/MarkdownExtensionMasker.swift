import Foundation

/// Which MacDown syntax extensions the masker handles. cmark-gfm does not know
/// these, so they are found before parsing and restored after rendering.
struct MarkdownExtensions: Equatable {
    var math = false
    var mathInlineDollar = false
    var highlight = false
    var superscript = false
    var underline = false
    var quote = false

    var isEmpty: Bool {
        !(math || highlight || superscript || underline || quote)
    }
}

/// Markdown text where extension spans were replaced by private-use
/// characters, plus the data needed to turn them into HTML.
///
/// Why masking: the spans must not be touched by the Markdown parser (for
/// example `$a_b$` must not become emphasis), and they must never be found
/// inside code. Placeholders are single private-use characters (U+E000 to
/// U+E011) that pass through every Markdown construct as plain text.
struct MaskedMarkdown {
    let text: String
    fileprivate let math: [String]
    fileprivate let hasTokens: Bool

    /// Replaces the placeholders in rendered HTML with the final markup.
    func unmask(_ html: String) -> String {
        guard hasTokens else { return html }
        let input = Array(html.utf8)
        var out = [UInt8]()
        out.reserveCapacity(input.count + 64)
        var i = 0
        while i < input.count {
            let b = input[i]
            // U+E000...U+E0FF is EE 80 80 ... EE 83 BF in UTF-8.
            if b == 0xEE, i + 2 < input.count, input[i + 1] == 0x80 {
                let code = Int(input[i + 2]) - 0x80
                if let tag = MaskToken.tag(for: code) {
                    out.append(contentsOf: tag.utf8)
                    i += 3
                    continue
                }
                if code == MaskToken.mathStart {
                    // Digits up to the end token.
                    var j = i + 3
                    var index = 0
                    while j < input.count, input[j] >= 0x30, input[j] <= 0x39 {
                        index = index * 10 + Int(input[j] - 0x30)
                        j += 1
                    }
                    if j + 2 < input.count, input[j] == 0xEE, input[j + 1] == 0x80,
                       Int(input[j + 2]) - 0x80 == MaskToken.mathEnd, index < math.count {
                        out.append(contentsOf: math[index].utf8)
                        i = j + 3
                        continue
                    }
                }
            }
            out.append(b)
            i += 1
        }
        return String(decoding: out, as: UTF8.self)
    }
}

enum MaskToken {
    static let markOpen = 0, markClose = 1, supOpen = 2, supClose = 3
    static let uOpen = 4, uClose = 5, qOpen = 6, qClose = 7
    static let mathStart = 0x10, mathEnd = 0x11

    static func bytes(_ code: Int) -> [UInt8] { [0xEE, 0x80, UInt8(0x80 + code)] }

    static func tag(for code: Int) -> String? {
        switch code {
        case markOpen: return "<mark>"
        case markClose: return "</mark>"
        case supOpen: return "<sup>"
        case supClose: return "</sup>"
        case uOpen: return "<u>"
        case uClose: return "</u>"
        case qOpen: return "<q>"
        case qClose: return "</q>"
        default: return nil
        }
    }
}

enum MarkdownExtensionMasker {
    static func mask(_ source: String, extensions: MarkdownExtensions) -> MaskedMarkdown {
        if extensions.isEmpty { return MaskedMarkdown(text: source, math: [], hasTokens: false) }
        let input = Array(source.utf8)
        // If the document already uses our placeholder characters, do not guess.
        if containsPlaceholder(input) { return MaskedMarkdown(text: source, math: [], hasTokens: false) }

        var scanner = Scanner(input: input, ext: extensions)
        let output = scanner.run()
        return MaskedMarkdown(text: String(decoding: output, as: UTF8.self),
                              math: scanner.math, hasTokens: scanner.didReplace)
    }

    private static func containsPlaceholder(_ input: [UInt8]) -> Bool {
        var i = 0
        while i + 2 < input.count {
            if input[i] == 0xEE, input[i + 1] == 0x80, input[i + 2] >= 0x80, input[i + 2] <= 0x91 { return true }
            i += 1
        }
        return false
    }
}

// MARK: - Scanner

private struct Scanner {
    let input: [UInt8]
    let ext: MarkdownExtensions
    private(set) var math: [String] = []
    private(set) var didReplace = false

    private struct Replacement {
        var start: Int
        var length: Int
        var bytes: [UInt8]
    }

    private enum Kind { case mark, underline, quote, sup, supParen }
    private struct Open {
        var kind: Kind
        var start: Int
        var length: Int
        var depth = 1   // Only for supParen.
    }

    init(input: [UInt8], ext: MarkdownExtensions) {
        self.input = input
        self.ext = ext
    }

    // Byte helpers.
    private static let newline: UInt8 = 0x0A, space: UInt8 = 0x20, tab: UInt8 = 0x09, cr: UInt8 = 0x0D
    private func isSpace(_ b: UInt8) -> Bool { b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D }
    private func isWord(_ b: UInt8) -> Bool {
        (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) || b >= 0x80
    }

    // MARK: Block level

    mutating func run() -> [UInt8] {
        var output = [UInt8]()
        output.reserveCapacity(input.count + 64)

        var lineStart = 0
        var paragraphStart = -1       // Start of the current text run, or -1.
        var fence: (char: UInt8, count: Int)?
        var previousBlank = true
        var inList = false

        func flush(upTo end: Int, _ scanner: inout Scanner, _ output: inout [UInt8]) {
            if paragraphStart >= 0 {
                scanner.scanParagraph(paragraphStart, end, into: &output)
                paragraphStart = -1
            }
        }

        while lineStart < input.count {
            var lineEnd = lineStart
            while lineEnd < input.count, input[lineEnd] != Scanner.newline { lineEnd += 1 }
            let next = min(lineEnd + 1, input.count)   // Includes the newline.

            let blank = isBlank(lineStart, lineEnd)
            if let open = fence {
                output.append(contentsOf: input[lineStart..<next])
                if isFence(lineStart, lineEnd, char: open.char, minCount: open.count) { fence = nil }
            } else if !blank, let opened = fenceOpening(lineStart, lineEnd) {
                flush(upTo: lineStart, &self, &output)
                output.append(contentsOf: input[lineStart..<next])
                fence = opened
            } else if blank {
                flush(upTo: lineStart, &self, &output)
                output.append(contentsOf: input[lineStart..<next])
            } else {
                let indent = leadingIndent(lineStart, lineEnd)
                let isListItem = listMarkerLength(lineStart, lineEnd) != nil
                if paragraphStart < 0 && previousBlank && indent >= 4 && !inList {
                    // Indented code block line: copy as is.
                    output.append(contentsOf: input[lineStart..<next])
                } else if paragraphStart < 0 && isReferenceDefinition(lineStart, lineEnd) {
                    output.append(contentsOf: input[lineStart..<next])
                } else {
                    if paragraphStart < 0 { paragraphStart = lineStart }
                }
                if isListItem { inList = true } else if previousBlank && indent == 0 { inList = false }
            }
            previousBlank = blank
            lineStart = next
        }
        flush(upTo: input.count, &self, &output)
        return output
    }

    private func isBlank(_ s: Int, _ e: Int) -> Bool {
        var i = s
        while i < e { if !isSpace(input[i]) { return false }; i += 1 }
        return true
    }

    private func leadingIndent(_ s: Int, _ e: Int) -> Int {
        var n = 0, i = s
        while i < e {
            if input[i] == Scanner.space { n += 1 } else if input[i] == Scanner.tab { n += 4 } else { break }
            i += 1
        }
        return n
    }

    private func listMarkerLength(_ s: Int, _ e: Int) -> Int? {
        var i = s
        while i < e, input[i] == Scanner.space { i += 1 }
        guard i < e else { return nil }
        if (input[i] == 0x2D || input[i] == 0x2A || input[i] == 0x2B), i + 1 < e, input[i + 1] == Scanner.space {
            return i + 2 - s
        }
        var j = i
        while j < e, input[j] >= 0x30, input[j] <= 0x39 { j += 1 }
        if j > i, j < e, input[j] == 0x2E || input[j] == 0x29, j + 1 < e, input[j + 1] == Scanner.space {
            return j + 2 - s
        }
        return nil
    }

    /// Skips spaces, tabs and block quote markers before a fence.
    private func fenceOpening(_ s: Int, _ e: Int) -> (char: UInt8, count: Int)? {
        var i = s
        while i < e, input[i] == Scanner.space || input[i] == Scanner.tab || input[i] == 0x3E { i += 1 }
        guard i < e, input[i] == 0x60 || input[i] == 0x7E else { return nil }
        let ch = input[i]
        var n = 0
        while i < e, input[i] == ch { n += 1; i += 1 }
        guard n >= 3 else { return nil }
        if ch == 0x60 {   // The info string of a backtick fence cannot contain backticks.
            var j = i
            while j < e { if input[j] == 0x60 { return nil }; j += 1 }
        }
        return (ch, n)
    }

    private func isFence(_ s: Int, _ e: Int, char: UInt8, minCount: Int) -> Bool {
        var i = s
        while i < e, input[i] == Scanner.space || input[i] == Scanner.tab || input[i] == 0x3E { i += 1 }
        var n = 0
        while i < e, input[i] == char { n += 1; i += 1 }
        guard n >= minCount else { return false }
        while i < e { if !isSpace(input[i]) { return false }; i += 1 }
        return true
    }

    private func isReferenceDefinition(_ s: Int, _ e: Int) -> Bool {
        var i = s
        var spaces = 0
        while i < e, input[i] == Scanner.space, spaces < 4 { i += 1; spaces += 1 }
        guard i < e, input[i] == 0x5B else { return false }
        i += 1
        while i < e, input[i] != 0x5D { i += 1 }
        return i + 1 < e && input[i] == 0x5D && input[i + 1] == 0x3A
    }

    // MARK: Inline level

    private mutating func scanParagraph(_ start: Int, _ end: Int, into output: inout [UInt8]) {
        var replacements: [Replacement] = []
        var stack: [Open] = []
        // After a failed search for a closer, later searches of that kind fail too.
        var noDisplayDollarClose = false
        var noParenClose = false
        var noBracketClose = false

        var i = start
        while i < end {
            let b = input[i]
            switch b {
            case 0x5C: // backslash
                if ext.math, i + 1 < end, input[i + 1] == 0x28 || input[i + 1] == 0x5B {
                    let isParen = input[i + 1] == 0x28
                    let skip = isParen ? noParenClose : noBracketClose
                    if !skip, let close = find(isParen ? [0x5C, 0x29] : [0x5C, 0x5D], from: i + 2, to: end) {
                        addMath(&replacements, i, close + 2, delimiters: isParen ? ("\\(", "\\)") : ("\\[", "\\]"),
                                content: i + 2..<close)
                        i = close + 2
                        continue
                    }
                    if isParen { noParenClose = true } else { noBracketClose = true }
                }
                i += min(2, end - i)
                continue

            case 0x60: // backtick: skip a code span
                var n = 0
                while i + n < end, input[i + n] == 0x60 { n += 1 }
                var j = i + n
                var closed = false
                while j < end {
                    if input[j] == 0x60 {
                        var m = 0
                        while j + m < end, input[j + m] == 0x60 { m += 1 }
                        if m == n { i = j + m; closed = true; break }
                        j += m
                    } else { j += 1 }
                }
                if !closed { i += n }
                continue

            case 0x3C: // '<': HTML tag or autolink
                if i + 1 < end, input[i + 1] == 0x21 || input[i + 1] == 0x2F || input[i + 1] == 0x3F
                    || (input[i + 1] | 0x20 >= 0x61 && input[i + 1] | 0x20 <= 0x7A) {
                    var j = i + 1
                    while j < end, input[j] != 0x3E { j += 1 }
                    if j < end { i = j + 1; continue }
                }
                i += 1
                continue

            case 0x5D: // ']' followed by '(': skip the link destination
                if i + 1 < end, input[i + 1] == 0x28 {
                    var depth = 0
                    var j = i + 1
                    while j < end {
                        if input[j] == 0x5C { j += 2; continue }
                        if input[j] == 0x28 { depth += 1 }
                        if input[j] == 0x29 { depth -= 1; if depth == 0 { break } }
                        j += 1
                    }
                    if j < end { i = j + 1; continue }
                }
                i += 1
                continue

            case 0x24 where ext.math: // '$'
                if i + 1 < end, input[i + 1] == 0x24 {
                    if !noDisplayDollarClose,
                       let close = find([0x24, 0x24], from: i + 2, to: end, skippingEscapes: true) {
                        addMath(&replacements, i, close + 2, delimiters: ("\\[", "\\]"), content: i + 2..<close)
                        i = close + 2
                        continue
                    }
                    noDisplayDollarClose = true
                    i += 2
                    continue
                }
                if ext.mathInlineDollar, i + 1 < end, !isSpace(input[i + 1]) {
                    if let close = nextDollar(from: i + 1, to: end),
                       !isSpace(input[close - 1]),
                       !(close + 1 < end && input[close + 1] >= 0x30 && input[close + 1] <= 0x39) {
                        addMath(&replacements, i, close + 1, delimiters: ("\\(", "\\)"), content: i + 1..<close)
                        i = close + 1
                        continue
                    }
                }
                i += 1
                continue

            case 0x3D where ext.highlight: // '=='
                if i + 1 < end, input[i + 1] == 0x3D, !(i + 2 < end && input[i + 2] == 0x3D),
                   !(i > start && input[i - 1] == 0x3D) {
                    handlePair(.mark, at: i, length: 2, end: end, start: start, stack: &stack, into: &replacements,
                               open: MaskToken.markOpen, close: MaskToken.markClose)
                    i += 2
                    continue
                }
                i += 1
                continue

            case 0x5F where ext.underline: // '_' (a single one)
                let runStart = i
                var n = 0
                while i < end, input[i] == 0x5F { n += 1; i += 1 }
                if n == 1 {
                    handlePair(.underline, at: runStart, length: 1, end: end, start: start, stack: &stack,
                               into: &replacements, open: MaskToken.uOpen, close: MaskToken.uClose)
                }
                continue

            case 0x22 where ext.quote: // '"'
                handlePair(.quote, at: i, length: 1, end: end, start: start, stack: &stack, into: &replacements,
                           open: MaskToken.qOpen, close: MaskToken.qClose)
                i += 1
                continue

            case 0x5E where ext.superscript: // '^'
                if i + 1 < end, input[i + 1] == 0x28 {
                    stack.append(Open(kind: .supParen, start: i, length: 2))
                    i += 2
                    continue
                }
                // Closing caret of a "^word^" form.
                if let top = stack.last, top.kind == .sup {
                    stack.removeLast()
                    replacements.append(Replacement(start: top.start, length: 1, bytes: MaskToken.bytes(MaskToken.supOpen)))
                    replacements.append(Replacement(start: i, length: 1, bytes: MaskToken.bytes(MaskToken.supClose)))
                    i += 1
                    continue
                }
                if i + 1 < end, !isSpace(input[i + 1]) {
                    // "^word": the word runs to whitespace or a closing caret.
                    var j = i + 1
                    while j < end, !isSpace(input[j]), input[j] != 0x5E { j += 1 }
                    if j < end, input[j] == 0x5E {
                        stack.append(Open(kind: .sup, start: i, length: 1))
                    } else {
                        // No closing caret: the word ends before trailing punctuation.
                        var wordEnd = j
                        while wordEnd > i + 1, [0x2E, 0x2C, 0x3B, 0x3A, 0x21, 0x3F, 0x29].contains(input[wordEnd - 1]) {
                            wordEnd -= 1
                        }
                        if wordEnd > i + 1 {
                            replacements.append(Replacement(start: i, length: 1, bytes: MaskToken.bytes(MaskToken.supOpen)))
                            replacements.append(Replacement(start: wordEnd, length: 0, bytes: MaskToken.bytes(MaskToken.supClose)))
                            i = wordEnd
                            continue
                        }
                    }
                }
                i += 1
                continue

            case 0x28: // '(' inside ^( ... )
                if let index = stack.lastIndex(where: { $0.kind == .supParen }) { stack[index].depth += 1 }
                i += 1
                continue

            case 0x29: // ')'
                if let index = stack.lastIndex(where: { $0.kind == .supParen }) {
                    stack[index].depth -= 1
                    if stack[index].depth == 0 {
                        let open = stack[index]
                        stack.removeSubrange(index...)
                        replacements.append(Replacement(start: open.start, length: 2, bytes: MaskToken.bytes(MaskToken.supOpen)))
                        replacements.append(Replacement(start: i, length: 1, bytes: MaskToken.bytes(MaskToken.supClose)))
                    }
                }
                i += 1
                continue

            default:
                i += 1
            }
        }

        // Apply replacements in source order.
        if replacements.isEmpty {
            output.append(contentsOf: input[start..<end])
            return
        }
        didReplace = true
        replacements.sort { $0.start < $1.start }
        var cursor = start
        for r in replacements {
            if r.start < cursor { continue }
            output.append(contentsOf: input[cursor..<r.start])
            output.append(contentsOf: r.bytes)
            cursor = r.start + r.length
        }
        output.append(contentsOf: input[cursor..<end])
    }

    /// Records an opener or closes the matching one, using flanking rules like
    /// CommonMark emphasis (an opener is followed by text, a closer follows text).
    private func handlePair(_ kind: Kind, at i: Int, length: Int, end: Int, start: Int,
                            stack: inout [Open], into replacements: inout [Replacement],
                            open: Int, close: Int) {
        let after = i + length < end ? input[i + length] : Scanner.space
        let before = i > start ? input[i - 1] : Scanner.space
        let canClose = !isSpace(before) && (kind == .underline ? !isWord(after) : true)
            && !(kind == .quote && isWord(after))
        let canOpen = !isSpace(after) && (kind == .underline || kind == .quote ? !isWord(before) : true)

        if canClose, let index = stack.lastIndex(where: { $0.kind == kind }) {
            let opener = stack[index]
            // Anything opened after the matching opener is dropped.
            stack.removeSubrange(index...)
            replacements.append(Replacement(start: opener.start, length: opener.length, bytes: MaskToken.bytes(open)))
            replacements.append(Replacement(start: i, length: length, bytes: MaskToken.bytes(close)))
        } else if canOpen {
            stack.append(Open(kind: kind, start: i, length: length))
        }
    }

    private mutating func addMath(_ replacements: inout [Replacement], _ start: Int, _ end: Int,
                                  delimiters: (String, String), content: Range<Int>) {
        let tex = String(decoding: input[content], as: UTF8.self)
        let escaped = tex.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let index = math.count
        math.append(delimiters.0 + escaped + delimiters.1)
        var bytes = MaskToken.bytes(MaskToken.mathStart)
        bytes.append(contentsOf: Array(String(index).utf8))
        bytes.append(contentsOf: MaskToken.bytes(MaskToken.mathEnd))
        replacements.append(Replacement(start: start, length: end - start, bytes: bytes))
    }

    private func find(_ needle: [UInt8], from: Int, to: Int, skippingEscapes: Bool = false) -> Int? {
        guard needle.count <= to - from else { return nil }
        var i = from
        while i + needle.count <= to {
            if skippingEscapes, input[i] == 0x5C { i += 2; continue }
            if input[i] == needle[0] {
                var match = true
                var k = 1
                while k < needle.count { if input[i + k] != needle[k] { match = false; break }; k += 1 }
                if match { return i }
            }
            i += 1
        }
        return nil
    }

    /// Next unescaped single `$`.
    private func nextDollar(from: Int, to: Int) -> Int? {
        var i = from
        while i < to {
            if input[i] == 0x5C { i += 2; continue }
            if input[i] == 0x24 { return i }
            i += 1
        }
        return nil
    }
}
