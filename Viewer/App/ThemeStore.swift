import SwiftUI
import ViewerCore

/// The predefined reading themes (YAML files in the app) and the one the user picked.
@MainActor
final class ThemeStore: ObservableObject {
    let themes: [ViewerTheme]
    @AppStorage("themeName") var themeName: String = ThemeCatalog.defaultName {
        willSet { objectWillChange.send() }
    }
    @AppStorage("textScale") var textScale: Double = 1.0 {
        willSet { objectWillChange.send() }
    }
    /// The user's accent color as `#rrggbb`; empty means the default blue.
    @AppStorage("accentHex") var accentHex: String = "" {
        willSet { objectWillChange.send() }
    }

    /// The accent as a SwiftUI color, or nil for the default.
    var accentColor: Color? { AccentCSS.normalized(accentHex).map { Color(hex: $0) } }

    init() {
        let folder = Bundle.main.resourceURL?.appendingPathComponent("BuiltinThemes") ?? URL(fileURLWithPath: "/")
        themes = ThemeCatalog.load(from: folder)
    }

    var current: ViewerTheme? { themes.first { $0.name == themeName } ?? themes.first { $0.name == ThemeCatalog.defaultName } ?? themes.first }

    func adjustScale(by step: Double) { textScale = min(2.0, max(0.7, ((textScale + step) * 20).rounded() / 20)) }
}
