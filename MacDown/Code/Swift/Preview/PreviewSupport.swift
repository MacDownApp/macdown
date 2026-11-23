import AppKit

/// Word and character counts for the status widget.
struct TextCount: Equatable {
    var words: Int
    var characters: Int            // Without line breaks.
    var charactersNoSpaces: Int    // Without spaces and line breaks.

    init(of text: String) {
        var wordCount = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            wordCount += 1
        }
        words = wordCount
        characters = text.unicodeScalars.filter { !CharacterSet.newlines.contains($0) }.count
        charactersNoSpaces = text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.count
    }
}

/// Reads colors as `getComputedStyle` reports them: `rgb(r, g, b)` or `rgba(r, g, b, a)`.
enum CSSColor {
    static func parse(_ text: String) -> NSColor? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.hasPrefix("rgb"), let open = trimmed.firstIndex(of: "("), let close = trimmed.lastIndex(of: ")") else { return nil }
        let numbers = trimmed[trimmed.index(after: open)..<close]
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" }).compactMap { Double($0) }
        guard numbers.count >= 3 else { return nil }
        let alpha = numbers.count > 3 ? numbers[3] : 1
        guard alpha > 0 else { return nil }   // Fully transparent: no color.
        return NSColor(srgbRed: CGFloat(numbers[0] / 255), green: CGFloat(numbers[1] / 255),
                       blue: CGFloat(numbers[2] / 255), alpha: CGFloat(alpha))
    }
}
