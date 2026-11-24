import SwiftUI
import ViewerCore

/// The reading and code fonts the user picked. They end up as CSS in the note page.
@MainActor
final class FontStore: ObservableObject {
    @AppStorage("fontSettings") private var stored: String = "" {
        willSet { objectWillChange.send() }
    }

    /// Font files in the app (JetBrains Mono Nerd Font, and Cartograph if it was in the build).
    let files: [String]

    init() {
        let folder = Bundle.main.resourceURL?.appendingPathComponent("Fonts")
        files = folder.flatMap { try? FileManager.default.contentsOfDirectory(atPath: $0.path) } ?? []
    }

    var settings: FontSettings {
        get { (try? JSONDecoder().decode(FontSettings.self, from: Data(stored.utf8))) ?? FontSettings() }
        set { stored = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "" }
    }

    var bodyChoices: [FontChoice] { FontCatalog.bodyChoices(files: files) }
    var codeChoices: [FontChoice] { FontCatalog.codeChoices(files: files) }

    /// CSS for the page; empty when nothing is customized.
    var css: String { FontCSS.css(settings: settings, files: files, baseURL: "md://app/Fonts/") }
}
