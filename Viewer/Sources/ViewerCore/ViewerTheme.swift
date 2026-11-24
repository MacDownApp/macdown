import Foundation

/// A reading theme: colors and token colors from a YAML theme file.
public struct ViewerTheme: Identifiable, Equatable {
    public var id: String { name }
    public let name: String
    let theme: Theme

    /// True if the theme has a light and a dark variant and so follows the system setting.
    public var followsSystem: Bool { theme.appearance == .both }

    /// True if the page is dark in this system appearance. Single-appearance themes always
    /// answer the same; themes with both variants follow the system.
    public func isDark(systemDark: Bool) -> Bool {
        theme.variant(isDark: systemDark).preview.background.luminance < 0.5
    }

    /// Page background as `#rrggbb`, for the area around the web view.
    public func backgroundHex(systemDark: Bool) -> String {
        theme.variant(isDark: systemDark).preview.background.cssString
    }

    /// Text color as `#rrggbb`, for the theme picker.
    public func textHex(systemDark: Bool) -> String { theme.variant(isDark: systemDark).preview.text.cssString }

    /// The heading color, as a sample of the theme's accent.
    public func accentHex(systemDark: Bool) -> String {
        let v = theme.variant(isDark: systemDark)
        return (v.tokens["heading"]?.color ?? v.tokens["link"]?.color ?? v.preview.text).cssString
    }

    /// CSS for this theme: page, headings, links, code, quotes and code token colors.
    public func css(systemDark: Bool) -> String {
        let dark = isDark(systemDark: systemDark)
        return ThemeCSS.css(for: theme.variant(isDark: systemDark), isDark: dark)
    }
}

public enum ThemeCatalog {
    public static let defaultName = "GitHub Light"

    /// Loads every `.yaml` theme in a folder (the app's `BuiltinThemes`). Broken files are skipped.
    public static func load(from directory: URL) -> [ViewerTheme] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { ["yaml", "yml"].contains($0.pathExtension.lowercased()) }
            .compactMap { file -> ViewerTheme? in
                guard let text = try? String(contentsOf: file, encoding: .utf8), let theme = try? Theme.parse(yaml: text) else { return nil }
                return ViewerTheme(name: theme.name, theme: theme)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
