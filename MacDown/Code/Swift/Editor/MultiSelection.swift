import Foundation

/// One replacement in a multi-cursor edit. `range` is in the coordinates of the
/// text before the edit.
struct TextEdit: Equatable {
    var range: NSRange
    var replacement: String
}

/// The result of a multi-cursor operation.
struct MultiEditResult: Equatable {
    var text: String
    /// New selections. Sorted, without overlap, never empty.
    var ranges: [NSRange]
    /// What changed, in ascending order. Apply them in one undo group.
    var edits: [TextEdit]
}

/// Multi-cursor logic as pure functions over text and UTF-16 ranges.
///
/// The text view cannot draw or edit several carets by itself, so the editor
/// asks this type "what happens if the user types X with these selections?"
/// and applies the answer in one step. Keeping it free of UI makes it easy to
/// test against single-cursor behavior.
///
/// Rules that hold for every result:
/// - ranges are sorted, do not overlap, and lie inside the new text;
/// - a caret never sits inside a grapheme cluster (an emoji, or a letter with
///   its accent) and deletes never cut one in half;
/// - carets that end up at the same place are merged.
enum MultiSelection {

    // MARK: Normalizing

    /// Clamps, sorts and merges. A caret that touches or lies inside a selection
    /// is absorbed by it. At least one range is always returned.
    static func normalize(_ ranges: [NSRange], length: Int) -> [NSRange] {
        let clamped = ranges.map { r -> NSRange in
            let loc = min(max(r.location, 0), length)
            let end = min(max(r.location + r.length, loc), length)
            return NSRange(location: loc, length: end - loc)
        }.sorted { ($0.location, $0.length) < ($1.location, $1.length) }

        var result: [NSRange] = []
        for r in clamped {
            guard let last = result.last else { result.append(r); continue }
            let lastEnd = last.location + last.length
            if r.length == 0, r.location <= lastEnd, (last.length > 0 || r.location == last.location) {
                continue   // A caret inside or at the edge of a selection, or a duplicate caret.
            }
            if last.length == 0, r.location <= last.location {
                result[result.count - 1] = r   // A selection that starts at an existing caret takes its place.
            } else if r.location < lastEnd {
                result[result.count - 1] = NSRange(location: last.location,
                                                   length: max(lastEnd, r.location + r.length) - last.location)
            } else {
                result.append(r)
            }
        }
        return result.isEmpty ? [NSRange(location: 0, length: 0)] : result
    }

    // MARK: Characters

    /// The character (grapheme cluster) that contains the UTF-16 unit at `index`.
    /// Unlike `NSString` alone, this keeps a Windows line ending (CR LF) together,
    /// as Swift and users see it as one character.
    private static func cluster(_ ns: NSString, at index: Int) -> NSRange {
        var range = ns.rangeOfComposedCharacterSequence(at: index)
        if range.length == 1, range.location + 1 < ns.length,
           ns.character(at: range.location) == 0x0D, ns.character(at: range.location + 1) == 0x0A {
            range.length = 2
        } else if range.length == 1, range.location > 0,
                  ns.character(at: range.location) == 0x0A, ns.character(at: range.location - 1) == 0x0D {
            range = NSRange(location: range.location - 1, length: 2)
        }
        return range
    }

    // MARK: Editing

    /// Replaces every selection with `replacement`. This is typing, or pasting
    /// the same text everywhere.
    static func replace(in text: String, ranges: [NSRange], with replacement: String) -> MultiEditResult {
        let normalized = normalize(ranges, length: (text as NSString).length)
        return apply(text, normalized, normalized.map { _ in replacement })
    }

    /// Pastes one piece of text per selection. If there are as many pieces as
    /// selections, each gets its own; otherwise every selection gets all of the text.
    static func paste(in text: String, ranges: [NSRange], pieces: [String]) -> MultiEditResult {
        let normalized = normalize(ranges, length: (text as NSString).length)
        if pieces.count == normalized.count { return apply(text, normalized, pieces) }
        return apply(text, normalized, normalized.map { _ in pieces.joined(separator: "\n") })
    }

    /// Backspace: removes the selection, or the character before each caret.
    static func deleteBackward(in text: String, ranges: [NSRange]) -> MultiEditResult {
        delete(in: text, ranges: ranges, forward: false)
    }

    /// Forward delete: removes the selection, or the character after each caret.
    static func deleteForward(in text: String, ranges: [NSRange]) -> MultiEditResult {
        delete(in: text, ranges: ranges, forward: true)
    }

    private static func delete(in text: String, ranges: [NSRange], forward: Bool) -> MultiEditResult {
        let ns = text as NSString
        let normalized = normalize(ranges, length: ns.length)
        let targets = normalized.map { r -> NSRange in
            if r.length > 0 { return r }
            if forward {
                guard r.location < ns.length else { return r }
                return cluster(ns, at: r.location)
            }
            guard r.location > 0 else { return r }
            // Delete the whole character, even if the caret is (wrongly) inside it.
            let before = cluster(ns, at: r.location - 1)
            return NSRange(location: before.location, length: max(r.location, NSMaxRange(before)) - before.location)
        }
        // Neighboring carets can ask to delete the same character. Merge those.
        let merged = mergeTouching(targets)
        return apply(text, merged, merged.map { _ in "" })
    }

    private static func mergeTouching(_ ranges: [NSRange]) -> [NSRange] {
        var result: [NSRange] = []
        for r in ranges.sorted(by: { $0.location < $1.location }) {
            if let last = result.last, r.length > 0, last.length > 0, r.location < last.location + last.length {
                result[result.count - 1] = NSRange(location: last.location,
                                                   length: max(last.location + last.length, r.location + r.length) - last.location)
            } else { result.append(r) }
        }
        return result
    }

    /// Applies one replacement per range (ascending, non-overlapping) and
    /// computes where the carets end up: right after each inserted text.
    private static func apply(_ text: String, _ ranges: [NSRange], _ replacements: [String]) -> MultiEditResult {
        let ns = text as NSString
        var output = ""
        var cursor = 0
        var delta = 0
        var edits: [TextEdit] = []
        var carets: [NSRange] = []
        for (range, replacement) in zip(ranges, replacements) {
            output += ns.substring(with: NSRange(location: cursor, length: range.location - cursor))
            output += replacement
            cursor = range.location + range.length
            let replacementLength = (replacement as NSString).length
            carets.append(NSRange(location: range.location + delta + replacementLength, length: 0))
            delta += replacementLength - range.length
            if range.length > 0 || !replacement.isEmpty { edits.append(TextEdit(range: range, replacement: replacement)) }
        }
        output += ns.substring(from: cursor)
        return MultiEditResult(text: output, ranges: normalize(carets, length: (output as NSString).length), edits: edits)
    }

    // MARK: Moving

    enum Direction { case left, right, up, down, lineStart, lineEnd, wordLeft, wordRight, documentStart, documentEnd }

    /// Moves every caret. A selection collapses to its start (left, up, ...) or its end.
    static func move(_ direction: Direction, in text: String, ranges: [NSRange]) -> [NSRange] {
        let ns = text as NSString
        let moved = normalize(ranges, length: ns.length).map { r -> NSRange in
            let start = r.location, end = r.location + r.length
            let target: Int
            switch direction {
            case .left: target = r.length > 0 ? start : (start > 0 ? cluster(ns, at: start - 1).location : 0)
            case .right: target = r.length > 0 ? end : (end < ns.length ? NSMaxRange(cluster(ns, at: end)) : end)
            case .lineStart: target = lineBounds(ns, at: start).start
            case .lineEnd: target = lineBounds(ns, at: end).contentsEnd
            case .up: target = verticalTarget(ns, from: start, down: false)
            case .down: target = verticalTarget(ns, from: end, down: true)
            case .wordLeft: target = wordBoundary(ns, from: start, forward: false)
            case .wordRight: target = wordBoundary(ns, from: end, forward: true)
            case .documentStart: target = 0
            case .documentEnd: target = ns.length
            }
            return NSRange(location: target, length: 0)
        }
        return normalize(moved, length: ns.length)
    }

    private static func lineBounds(_ ns: NSString, at location: Int) -> (start: Int, end: Int, contentsEnd: Int) {
        var start = 0, end = 0, contentsEnd = 0
        ns.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: min(location, ns.length), length: 0))
        return (start, end, contentsEnd)
    }

    private static func verticalTarget(_ ns: NSString, from location: Int, down: Bool) -> Int {
        let line = lineBounds(ns, at: location)
        let column = location - line.start
        let other: (start: Int, end: Int, contentsEnd: Int)
        if down {
            guard line.end < ns.length else { return ns.length }
            other = lineBounds(ns, at: line.end)
        } else {
            guard line.start > 0 else { return 0 }
            other = lineBounds(ns, at: line.start - 1)
        }
        var target = min(other.start + column, other.contentsEnd)
        if target < ns.length, target > 0 {   // Do not land inside a character.
            target = cluster(ns, at: target).location
        }
        return target
    }

    private static func isWordCharacter(_ unit: unichar) -> Bool {
        unit > 0x7F || (unit >= 0x30 && unit <= 0x39) || (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A) || unit == 0x5F
    }

    private static func wordBoundary(_ ns: NSString, from location: Int, forward: Bool) -> Int {
        var i = location
        if forward {
            while i < ns.length, !isWordCharacter(ns.character(at: i)) { i += 1 }
            while i < ns.length, isWordCharacter(ns.character(at: i)) { i += 1 }
        } else {
            while i > 0, !isWordCharacter(ns.character(at: i - 1)) { i -= 1 }
            while i > 0, isWordCharacter(ns.character(at: i - 1)) { i -= 1 }
        }
        return i
    }

    // MARK: Adding carets and selections

    /// ⌘D: if the last selection is a caret, select the word it is in; otherwise
    /// add the next occurrence of the selected text (wrapping around the end).
    static func addNextOccurrence(in text: String, ranges: [NSRange]) -> [NSRange] {
        let ns = text as NSString
        var current = normalize(ranges, length: ns.length)
        guard let last = current.last else { return current }

        if last.length == 0 {
            let word = wordRange(ns, at: last.location)
            if word.length > 0 { current[current.count - 1] = word }
            return normalize(current, length: ns.length)   // The word may reach other carets.
        }
        let needle = ns.substring(with: last)
        // First look after the last selection, then wrap around to the start.
        let windows = [NSRange(location: NSMaxRange(last), length: ns.length - NSMaxRange(last)),
                       NSRange(location: 0, length: last.location)]
        for window in windows {
            var from = window.location
            while from < NSMaxRange(window) {
                let hit = ns.range(of: needle, options: [], range: NSRange(location: from, length: NSMaxRange(window) - from))
                if hit.location == NSNotFound { break }
                if !current.contains(where: { NSIntersectionRange($0, hit).length > 0 }) {
                    return normalize(current + [hit], length: ns.length)
                }
                from = NSMaxRange(hit)
            }
        }
        return current
    }

    /// ⌘⇧L: select every occurrence of the selected text (or of the word at a caret).
    static func selectAllOccurrences(in text: String, ranges: [NSRange]) -> [NSRange] {
        let ns = text as NSString
        let current = normalize(ranges, length: ns.length)
        guard var seed = current.last else { return current }
        if seed.length == 0 { seed = wordRange(ns, at: seed.location) }
        guard seed.length > 0 else { return current }
        let needle = ns.substring(with: seed)
        var found: [NSRange] = []
        var from = 0
        while from < ns.length {
            let hit = ns.range(of: needle, options: [], range: NSRange(location: from, length: ns.length - from))
            if hit.location == NSNotFound { break }
            found.append(hit)
            from = NSMaxRange(hit)
        }
        return normalize(found, length: ns.length)
    }

    /// Adds a caret on the line above (or below) the first (or last) caret, at the same column.
    static func addCaret(_ side: Direction, in text: String, ranges: [NSRange]) -> [NSRange] {
        let ns = text as NSString
        let current = normalize(ranges, length: ns.length)
        guard side == .up || side == .down else { return current }
        let base = side == .up ? current.first! : current.last!
        let anchor = side == .up ? base.location : base.location + base.length
        let target = verticalTarget(ns, from: anchor, down: side == .down)
        return normalize(current + [NSRange(location: target, length: 0)], length: ns.length)
    }

    /// Column selection: a range per line between two offsets, from the column of
    /// `anchor` to the column of `head` (clamped to short lines).
    static func columnSelection(in text: String, anchor: Int, head: Int) -> [NSRange] {
        let ns = text as NSString
        let a = lineBounds(ns, at: min(anchor, ns.length)), h = lineBounds(ns, at: min(head, ns.length))
        let colA = min(anchor, ns.length) - a.start, colH = min(head, ns.length) - h.start
        let (left, right) = (min(colA, colH), max(colA, colH))
        var result: [NSRange] = []
        var lineStart = min(a.start, h.start)
        let lastStart = max(a.start, h.start)
        while lineStart <= lastStart {
            let line = lineBounds(ns, at: lineStart)
            let from = min(line.start + left, line.contentsEnd), to = min(line.start + right, line.contentsEnd)
            result.append(NSRange(location: from, length: to - from))
            if line.end >= ns.length || line.end == lineStart { break }
            lineStart = line.end
        }
        return normalize(result, length: ns.length)
    }

    private static func wordRange(_ ns: NSString, at location: Int) -> NSRange {
        var start = location, end = location
        while start > 0, isWordCharacter(ns.character(at: start - 1)) { start -= 1 }
        while end < ns.length, isWordCharacter(ns.character(at: end)) { end += 1 }
        return NSRange(location: start, length: end - start)
    }
}
