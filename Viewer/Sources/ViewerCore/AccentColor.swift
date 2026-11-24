import Foundation

/// The user's accent color, applied to links, wikilinks, tags and selections in a note.
public enum AccentCSS {
    /// Colors offered in the settings (name, `#rrggbb`).
    public static let presets: [(name: String, hex: String)] = [
        ("Blue", "#0a84ff"), ("Indigo", "#5e5ce6"), ("Purple", "#a259e6"), ("Pink", "#ff375f"),
        ("Red", "#ff453a"), ("Orange", "#ff9f0a"), ("Yellow", "#e6b800"), ("Green", "#30b350"),
        ("Teal", "#2bb5c8"), ("Graphite", "#8e8e93"),
    ]

    /// `#rrggbb` for a valid color (also accepts `#rgb`), or nil. Nothing else can get into the CSS.
    public static func normalized(_ hex: String) -> String? {
        guard hex.hasPrefix("#"), let color = ThemeColor(hex: hex), color.alpha >= 1 else { return nil }
        return color.cssString
    }

    /// CSS for the page. Empty for "no accent" (the theme's own colors stay).
    public static func css(hex: String) -> String {
        guard let color = normalized(hex), let parsed = ThemeColor(hex: color) else { return "" }
        let soft = parsed.withAlpha(0.18).cssString
        let selection = parsed.withAlpha(0.3).cssString
        // "html body" is more specific than the theme's own `body a`.
        return """
        html body a, html body a.wikilink { color: \(color); }
        html body .tag { color: \(color); background: \(soft); }
        html body .embed-note { border-left-color: \(color); }
        html body input[type=checkbox] { accent-color: \(color); }
        html body ::selection { background: \(selection); }
        """
    }

    /// A readable text color (black or white) to put on top of the accent, for badges and buttons.
    public static func onAccentIsDark(_ hex: String) -> Bool {
        guard let color = normalized(hex).flatMap(ThemeColor.init(hex:)) else { return false }
        return color.luminance > 0.6
    }
}
