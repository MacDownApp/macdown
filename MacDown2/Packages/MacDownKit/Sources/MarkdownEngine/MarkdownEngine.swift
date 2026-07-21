import AppKit
import Foundation

/// MarkdownEngine — parses Markdown and produces attributed-string previews.
///
/// See planning/epics/ and planning/MIGRATION_PLAN.md § 4 for the full role.
/// For EPIC-02 this is a minimal read-only renderer used by the `Preview`
/// module so the split source/preview pane is functional. Full AST-based
/// rendering, themes, and scroll sync come in E06/E07.
public enum MarkdownEngine {
    public static let moduleName = "MarkdownEngine"

    /// Renders plain Markdown text into a simple attributed string.
    ///
    /// This is intentionally lightweight: it only styles headings and code
    /// spans/blocks so the preview pane is useful out of the box. Returns `nil`
    /// only for malformed input that cannot be represented as a string.
    ///
    /// Isolated to `@MainActor` because it constructs AppKit types (`NSFont`,
    /// `NSColor`, `NSAttributedString`) which are only safe to touch on the main
    /// thread. Callers today are all on the main actor (SwiftUI `View.body`).
    @MainActor
    public static func renderAttributed(_ markdown: String) -> NSAttributedString? {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let heading = headingAttributedString(for: trimmed) {
                result.append(heading)
            } else if trimmed.hasPrefix("```") {
                result.append(codeBlockAttributedString(for: trimmed))
            } else if let inline = inlineCodeAttributedString(for: trimmed) {
                result.append(inline)
            } else {
                result.append(NSAttributedString(string: trimmed, attributes: baseAttributes))
            }

            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }

    // MARK: - Private helpers

    private static var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.textColor,
        ]
    }

    private static func headingAttributedString(for line: String) -> NSAttributedString? {
        let prefixes = ["# ", "## ", "### ", "#### ", "##### ", "###### "]
        guard let prefix = prefixes.first(where: line.hasPrefix) else { return nil }
        let level = prefix.count - 1
        let text = String(line.dropFirst(prefix.count))
        let fontSize = max(12, 28 - level * 4)
        let font = NSFont.systemFont(ofSize: CGFloat(fontSize), weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor,
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    private static func inlineCodeAttributedString(for line: String) -> NSAttributedString? {
        guard line.contains("`") else { return nil }
        let result = NSMutableAttributedString()
        var buffer = ""
        var inCode = false

        for character in line {
            if character == "`" {
                if !buffer.isEmpty {
                    let attrs: [NSAttributedString.Key: Any] = inCode
                        ? [
                            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium),
                            .foregroundColor: NSColor.systemOrange,
                            .backgroundColor: NSColor.separatorColor.withAlphaComponent(0.1),
                        ]
                        : baseAttributes
                    result.append(NSAttributedString(string: buffer, attributes: attrs))
                    buffer = ""
                }
                inCode.toggle()
            } else {
                buffer.append(character)
            }
        }

        if !buffer.isEmpty {
            result.append(NSAttributedString(string: buffer, attributes: baseAttributes))
        }

        return result
    }

    private static func codeBlockAttributedString(for line: String) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        return NSAttributedString(string: line, attributes: attributes)
    }
}
