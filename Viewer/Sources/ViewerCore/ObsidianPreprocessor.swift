import Foundation

/// Where Obsidian-only syntax is turned into HTML or plain Markdown, before the
/// Markdown parser runs. Code (fenced blocks and inline code) is never touched.
///
/// - `%%comment%%` is removed.
/// - `#tag` becomes a styled span.
/// - `![[image.png]]`, `![[audio.mp3]]`, `![[video.mp4]]` become media elements; `![[Note]]` and
///   `![[Note#Heading]]` on their own line show that note (or section) inline, up to 3 levels deep.
/// - `[[Note]]`, `[[Note#Heading|Alias]]` become links the app handles (`md://note/...`);
///   links that match no note are shown as unresolved text.
struct ObsidianContext {
    let resolver: VaultResolving
    let note: String
    let loadNote: (String) -> String?
    var depth = 0
    var visited: Set<String> = []
}

enum ObsidianPreprocessor {
    static let maxEmbedDepth = 3

    static func process(_ text: String, context: ObsidianContext) -> String {
        splitCode(text).map { piece in piece.isCode ? piece.text : transform(piece.text, context) }.joined()
    }

    // MARK: Code detection

    struct Piece { var text: String; var isCode: Bool }

    /// Splits text into code and non-code pieces: fenced blocks (whole lines) and inline code.
    static func splitCode(_ text: String) -> [Piece] {
        var pieces: [Piece] = []
        var plain = ""
        var fence: (char: Character, count: Int)?

        func flushPlain() {
            if !plain.isEmpty { pieces.append(contentsOf: splitInlineCode(plain)); plain = "" }
        }
        for line in linesKeepingNewlines(text) {
            if let open = fence {
                pieces.append(Piece(text: line, isCode: true))
                if isFenceLine(line, char: open.char, minCount: open.count) { fence = nil }
            } else if let opened = fenceOpening(line) {
                flushPlain()
                pieces.append(Piece(text: line, isCode: true))
                fence = opened
            } else {
                plain += line
            }
        }
        flushPlain()
        return pieces
    }

    /// The lines of a text, each with its line break (the last one only if the text ends with one).
    static func linesKeepingNewlines(_ text: String) -> [String] {
        var lines: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if ch == "\n" || ch == "\r\n" { lines.append(current); current = "" }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    private static func fenceOpening(_ line: String) -> (char: Character, count: Int)? {
        let trimmed = line.drop { $0 == " " || $0 == "\t" || $0 == ">" }
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
        let count = trimmed.prefix { $0 == first }.count
        guard count >= 3 else { return nil }
        if first == "`", trimmed.dropFirst(count).contains("`") { return nil }
        return (first, count)
    }

    private static func isFenceLine(_ line: String, char: Character, minCount: Int) -> Bool {
        let trimmed = line.drop { $0 == " " || $0 == "\t" || $0 == ">" }
        let run = trimmed.prefix { $0 == char }.count
        return run >= minCount && trimmed.dropFirst(run).allSatisfy { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" }
    }

    private static func splitInlineCode(_ text: String) -> [Piece] {
        var pieces: [Piece] = []
        var current = ""
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            guard chars[i] == "`" else { current.append(chars[i]); i += 1; continue }
            var n = 0
            while i + n < chars.count, chars[i + n] == "`" { n += 1 }
            // Find a closing run of exactly n backticks.
            var j = i + n
            var close: Int?
            while j < chars.count {
                if chars[j] == "`" {
                    var m = 0
                    while j + m < chars.count, chars[j + m] == "`" { m += 1 }
                    if m == n { close = j; break }
                    j += m
                } else { j += 1 }
            }
            if let close = close {
                if !current.isEmpty { pieces.append(Piece(text: current, isCode: false)); current = "" }
                pieces.append(Piece(text: String(chars[i..<(close + n)]), isCode: true))
                i = close + n
            } else {
                current.append(contentsOf: chars[i..<(i + n)])
                i += n
            }
        }
        if !current.isEmpty { pieces.append(Piece(text: current, isCode: false)) }
        return pieces
    }

    // MARK: Transforms

    private static let comment = try! NSRegularExpression(pattern: "%%[\\s\\S]*?%%")
    private static let tag = try! NSRegularExpression(
        pattern: "(?<![\\w/&#\"'=\\[\\(>])#([\\p{L}\\p{N}_/\\-]*[\\p{L}_/\\-][\\p{L}\\p{N}_/\\-]*)")
    private static let embedOwnLine = try! NSRegularExpression(
        pattern: "^[ \\t]*!\\[\\[([^\\]\\n|]+)(?:\\|([^\\]\\n]*))?\\]\\][ \\t]*$", options: [.anchorsMatchLines])
    private static let embed = try! NSRegularExpression(pattern: "!\\[\\[([^\\]\\n|]+)(?:\\|([^\\]\\n]*))?\\]\\]")
    private static let wikilink = try! NSRegularExpression(pattern: "\\[\\[([^\\]\\n|]+)(?:\\|([^\\]\\n]*))?\\]\\]")

    private static func transform(_ text: String, _ context: ObsidianContext) -> String {
        var out = text
        out = replace(comment, in: out) { _ in "" }
        out = replace(tag, in: out) { m in "<span class=\"tag\">#\(HTMLEscape.escape(m[1]))</span>" }
        out = replace(embedOwnLine, in: out) { m in embedBlock(target: m[1], alias: m.count > 2 ? m[2] : "", context) }
        out = replace(embed, in: out) { m in embedInline(target: m[1], alias: m.count > 2 ? m[2] : "", context) }
        out = replace(wikilink, in: out) { m in link(target: m[1], alias: m.count > 2 ? m[2] : "", context) }
        return out
    }

    /// Replaces every match; `groups[0]` is the whole match, the others the capture groups ("" if missing).
    private static func replace(_ regex: NSRegularExpression, in text: String, _ make: ([String]) -> String) -> String {
        let ns = text as NSString
        var result = ""
        var last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            var groups: [String] = []
            for g in 0..<match.numberOfRanges {
                let r = match.range(at: g)
                groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
            }
            result += make(groups)
            last = match.range.location + match.range.length
        }
        return result + ns.substring(from: last)
    }

    // MARK: Links

    static func noteURL(path: String, fragment: String?) -> String {
        var url = "md://note/" + (path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path)
        if let fragment = fragment, !fragment.isEmpty {
            url += "#" + (fragment.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? fragment)
        }
        return url
    }

    static func fileURL(path: String) -> String {
        "md://vault/" + (path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path)
    }

    private static func splitTarget(_ target: String) -> (name: String, fragment: String?) {
        let trimmed = target.trimmingCharacters(in: .whitespaces)
        guard let hash = trimmed.firstIndex(of: "#") else { return (trimmed, nil) }
        return (String(trimmed[trimmed.startIndex..<hash]), String(trimmed[trimmed.index(after: hash)...]))
    }

    private static func link(target: String, alias: String, _ context: ObsidianContext) -> String {
        let (name, fragment) = splitTarget(target)
        if (name as NSString).pathExtension.lowercased() == "pdf" {
            guard let path = context.resolver.resolveAttachment(name, from: context.note) else {
                return "<span class=\"wikilink unresolved\">\(HTMLEscape.escape(alias.isEmpty ? name : alias))</span>"
            }
            let suffix = fragment.map { "#" + ($0.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? $0) } ?? ""
            return "<a class=\"wikilink\" href=\"\(fileURL(path: path))\(suffix)\">\(HTMLEscape.escape(alias.isEmpty ? (name as NSString).lastPathComponent : alias))</a>"
        }
        let shown: String
        if !alias.isEmpty {
            shown = alias
        } else {
            let base = name.isEmpty ? (context.note as NSString).deletingPathExtension.components(separatedBy: "/").last ?? name : name
            shown = HTMLEscape.escape(fragment.map { "\(base) > \($0)" } ?? base)
        }
        if let path = context.resolver.resolveNote(target, from: context.note) {
            return "<a class=\"wikilink\" href=\"\(noteURL(path: path, fragment: fragment))\">\(alias.isEmpty ? shown : HTMLEscape.escape(alias))</a>"
        }
        return "<span class=\"wikilink unresolved\">\(alias.isEmpty ? shown : HTMLEscape.escape(alias))</span>"
    }

    // MARK: Embeds

    private static let images: Set<String> = ["png", "jpg", "jpeg", "gif", "svg", "webp", "bmp", "heic", "avif", "tif", "tiff"]
    private static let audio: Set<String> = ["mp3", "m4a", "wav", "ogg", "flac", "aac"]
    private static let video: Set<String> = ["mp4", "mov", "webm", "m4v", "ogv"]

    private static func embedInline(target: String, alias: String, _ context: ObsidianContext) -> String {
        let (name, fragment) = splitTarget(target)
        let ext = (name as NSString).pathExtension.lowercased()
        let escapedName = HTMLEscape.escape(name)
        if !images.contains(ext) && !audio.contains(ext) && !video.contains(ext) && ext != "pdf" {
            // A note embedded inside a line: show a link instead.
            return link(target: target, alias: alias, context)
        }
        guard let path = context.resolver.resolveAttachment(name, from: context.note) else {
            return "<span class=\"wikilink unresolved\">\(escapedName)</span>"
        }
        let src = fileURL(path: path)
        if images.contains(ext) {
            var size = ""
            let parts = alias.split(separator: "x", maxSplits: 1).map(String.init)
            if let w = parts.first.flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) }) {
                size += " width=\"\(w)\""
                if parts.count > 1, let h = Int(parts[1].trimmingCharacters(in: .whitespaces)) { size += " height=\"\(h)\"" }
            }
            let alt = (alias.isEmpty || Int(alias.prefix(1)) != nil) ? escapedName : HTMLEscape.escape(alias)
            return "<img src=\"\(src)\" alt=\"\(alt)\"\(size)>"
        }
        if audio.contains(ext) { return "<audio controls src=\"\(src)\"></audio>" }
        if video.contains(ext) { return "<video controls playsinline src=\"\(src)\"></video>" }
        return pdfCard(src: src + (fragment.map { "#" + ($0.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? $0) } ?? ""),
                       name: (name as NSString).lastPathComponent, alias: alias, fragment: fragment)
    }

    /// A tappable card for a PDF. The app opens it in its own PDF viewer (`#page=3` opens that page).
    static func pdfCard(src: String, name: String, alias: String, fragment: String?) -> String {
        let page = fragment.flatMap(PDFLink.page(fromFragment:)).map { "Page \($0)" } ?? "Tap to open"
        let title = alias.isEmpty || Int(alias.prefix(1)) != nil ? name : alias
        return "<a class=\"pdf-embed\" href=\"\(src)\"><span class=\"pdf-badge\">PDF</span>"
            + "<span class=\"pdf-name\">\(HTMLEscape.escape(title))</span><span class=\"pdf-hint\">\(page)</span></a>"
    }

    private static func embedBlock(target: String, alias: String, _ context: ObsidianContext) -> String {
        let (name, fragment) = splitTarget(target)
        let ext = (name as NSString).pathExtension.lowercased()
        let isMedia = images.contains(ext) || audio.contains(ext) || video.contains(ext) || ext == "pdf"
        guard !isMedia else { return embedInline(target: target, alias: alias, context) }

        guard let path = context.resolver.resolveNote(target, from: context.note) else {
            return "<span class=\"wikilink unresolved\">\(HTMLEscape.escape(name))</span>"
        }
        guard context.depth < maxEmbedDepth, !context.visited.contains(path), !context.note.isEmpty,
              path != context.note, let raw = context.loadNote(path) else {
            return link(target: target, alias: alias, context)
        }
        var body = FrontMatter.split(raw).body
        if let fragment = fragment, !fragment.isEmpty { body = section(of: body, heading: fragment) ?? body }
        var inner = context
        inner.depth += 1
        inner.visited.insert(path)
        let processed = process(body, context: ObsidianContext(
            resolver: context.resolver, note: path, loadNote: context.loadNote,
            depth: inner.depth, visited: inner.visited))
        let title = HTMLEscape.escape(((path as NSString).deletingPathExtension as NSString).lastPathComponent)
        // Blank lines around the Markdown make the parser read it as Markdown inside the HTML block.
        return "\n<div class=\"embed-note\">\n<div class=\"embed-title\"><a class=\"wikilink\" href=\"\(noteURL(path: path, fragment: fragment))\">\(title)</a></div>\n\n\(processed)\n\n</div>\n"
    }

    /// The part of a note under a heading, up to the next heading of the same or a higher level.
    static func section(of text: String, heading: String) -> String? {
        let wanted = heading.trimmingCharacters(in: .whitespaces).lowercased()
        var collected: [String] = []
        var level: Int?
        var inFence = false
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("```") || line.hasPrefix("~~~") { inFence.toggle() }
            let hashes = line.prefix { $0 == "#" }.count
            let isHeading = !inFence && hashes >= 1 && hashes <= 6 && line.dropFirst(hashes).first == " "
            if let current = level {
                if isHeading && hashes <= current { break }
                collected.append(line)
            } else if isHeading, line.dropFirst(hashes + 1).trimmingCharacters(in: .whitespaces).lowercased() == wanted {
                level = hashes
                collected.append(line)
            }
        }
        return level == nil ? nil : collected.joined(separator: "\n")
    }
}

// MARK: - Front matter

enum FrontMatter {
    /// Splits a leading `---` YAML block off a note.
    static func split(_ text: String) -> (yaml: String?, body: String) {
        guard text.hasPrefix("---\n") || text.hasPrefix("---\r\n") else { return (nil, text) }
        let lines = text.components(separatedBy: "\n")
        for index in 1..<max(lines.count, 1) where lines[index].trimmingCharacters(in: .whitespacesAndNewlines) == "---"
            || lines[index].trimmingCharacters(in: .whitespacesAndNewlines) == "..." {
            let yaml = lines[1..<index].joined(separator: "\n")
            let body = lines[(index + 1)...].joined(separator: "\n")
            return (yaml, body)
        }
        return (nil, text)
    }
}
