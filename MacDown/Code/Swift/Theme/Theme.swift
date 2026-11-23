import Foundation
import Yams

/// Style of one syntax or Markdown token. Shared by the editor and the preview.
struct TokenStyle: Equatable {
    var color: ThemeColor?
    var bold = false
    var italic = false
}

struct EditorColors: Equatable {
    var background: ThemeColor
    var text: ThemeColor
    var caret: ThemeColor
    var selection: ThemeColor
    var lineHighlight: ThemeColor?
}

struct PreviewStyle: Equatable {
    var background: ThemeColor
    var text: ThemeColor
    var contentWidth: Int?
    /// Path to an extra CSS file, relative to the config directory.
    var extraCSS: String?
}

/// Colors and token styles for one appearance (light or dark).
struct ThemeVariant: Equatable {
    var editor: EditorColors
    var tokens: [String: TokenStyle]
    var preview: PreviewStyle
}

struct Theme: Equatable {
    enum Appearance: String, Equatable {
        case light, dark, both
    }

    var name: String
    var appearance: Appearance
    var light: ThemeVariant?
    var dark: ThemeVariant?

    /// The variant to use. Single-appearance themes return their only variant.
    func variant(isDark: Bool) -> ThemeVariant {
        switch appearance {
        case .light: return light!
        case .dark: return dark!
        case .both: return (isDark ? dark : light)!
        }
    }
}

enum ThemeError: Error, Equatable, LocalizedError {
    case notAMapping
    case missing(String)
    case invalid(key: String, expected: String)

    var errorDescription: String? {
        switch self {
        case .notAMapping: return "A theme file must contain key/value pairs at the top level."
        case let .missing(key): return "Missing required key “\(key)”."
        case let .invalid(key, expected): return "Invalid value for “\(key)”. Expected \(expected)."
        }
    }
}

// MARK: - Parsing

extension Theme {
    static func parse(yaml: String) throws -> Theme {
        guard let root = try Yams.load(yaml: yaml) else { throw ThemeError.notAMapping }
        guard let dict = root as? [String: Any] else { throw ThemeError.notAMapping }

        guard let name = dict["name"] as? String, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ThemeError.missing("name")
        }
        let appearance: Appearance
        if let value = dict["appearance"] {
            guard let text = value as? String, let parsed = Appearance(rawValue: text.lowercased()) else {
                throw ThemeError.invalid(key: "appearance", expected: "light, dark or both")
            }
            appearance = parsed
        } else {
            appearance = .light
        }

        var theme = Theme(name: name, appearance: appearance)
        switch appearance {
        case .light:
            theme.light = try parseVariant(dict, path: "")
        case .dark:
            theme.dark = try parseVariant(dict, path: "")
        case .both:
            guard let light = dict["light"] as? [String: Any] else { throw ThemeError.missing("light") }
            guard let dark = dict["dark"] as? [String: Any] else { throw ThemeError.missing("dark") }
            theme.light = try parseVariant(light, path: "light.")
            theme.dark = try parseVariant(dark, path: "dark.")
        }
        return theme
    }

    private init(name: String, appearance: Appearance) {
        self.name = name
        self.appearance = appearance
    }

    private static func parseVariant(_ dict: [String: Any], path: String) throws -> ThemeVariant {
        guard let editor = dict["editor"] as? [String: Any] else { throw ThemeError.missing("\(path)editor") }
        let background = try color(editor, "background", path: "\(path)editor.", required: true)!
        let text = try color(editor, "text", path: "\(path)editor.", required: true)!
        let caret = try color(editor, "caret", path: "\(path)editor.", required: false) ?? text
        let selection = try color(editor, "selection", path: "\(path)editor.", required: false) ?? text.withAlpha(0.2)
        let line = try color(editor, "line-highlight", path: "\(path)editor.", required: false)
        let editorColors = EditorColors(background: background, text: text, caret: caret,
                                        selection: selection, lineHighlight: line)

        var tokens: [String: TokenStyle] = [:]
        if let raw = dict["tokens"] {
            guard let map = raw as? [String: Any] else {
                throw ThemeError.invalid(key: "\(path)tokens", expected: "a mapping")
            }
            for (key, value) in map {
                guard let style = value as? [String: Any] else {
                    throw ThemeError.invalid(key: "\(path)tokens.\(key)", expected: "a mapping")
                }
                var token = TokenStyle()
                token.color = try color(style, "color", path: "\(path)tokens.\(key).", required: false)
                if let bold = style["bold"] {
                    guard let flag = bold as? Bool else {
                        throw ThemeError.invalid(key: "\(path)tokens.\(key).bold", expected: "true or false")
                    }
                    token.bold = flag
                }
                if let weight = style["weight"] as? String { token.bold = token.bold || weight == "bold" }
                if let italic = style["italic"] {
                    guard let flag = italic as? Bool else {
                        throw ThemeError.invalid(key: "\(path)tokens.\(key).italic", expected: "true or false")
                    }
                    token.italic = flag
                }
                tokens[key] = token
            }
        }

        var preview = PreviewStyle(background: background, text: text)
        if let raw = dict["preview"] {
            guard let map = raw as? [String: Any] else {
                throw ThemeError.invalid(key: "\(path)preview", expected: "a mapping")
            }
            preview.background = try color(map, "background", path: "\(path)preview.", required: false) ?? background
            preview.text = try color(map, "text", path: "\(path)preview.", required: false) ?? text
            if let width = map["content-width"] {
                guard let number = width as? Int, number > 0 else {
                    throw ThemeError.invalid(key: "\(path)preview.content-width", expected: "a positive number")
                }
                preview.contentWidth = number
            }
            if let css = map["extra-css"] as? String, !css.isEmpty { preview.extraCSS = css }
        }
        return ThemeVariant(editor: editorColors, tokens: tokens, preview: preview)
    }

    private static func color(_ dict: [String: Any], _ key: String, path: String, required: Bool) throws -> ThemeColor? {
        guard let value = dict[key] else {
            if required { throw ThemeError.missing("\(path)\(key)") }
            return nil
        }
        guard let text = value as? String, let color = ThemeColor(hex: text) else {
            throw ThemeError.invalid(key: "\(path)\(key)", expected: "a quoted hex color such as \"#RRGGBB\"")
        }
        return color
    }
}
