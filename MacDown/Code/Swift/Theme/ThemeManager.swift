import Foundation

/// Finds and loads themes.
///
/// Themes are YAML files. Built-in themes live in the app bundle. User themes
/// live in `~/.config/macdown/themes` and override built-in themes that have
/// the same name. Listing only reads file names. A theme file is parsed only
/// when it is selected, so start-up cost does not grow with the number of themes.
final class ThemeManager {
    static let fallbackName = "GitHub Light"

    struct Entry: Equatable {
        var name: String
        var url: URL
        var isBuiltIn: Bool
    }

    private let builtInDirectory: URL?
    private let userDirectory: URL
    private let fileManager: FileManager

    /// Last theme that loaded without errors. Used when a theme file breaks.
    private(set) var lastGoodTheme: Theme?
    /// Message for the most recent load problem, for a non-blocking notice.
    private(set) var lastError: Error?

    init(builtInDirectory: URL? = Bundle.main.url(forResource: "BuiltinThemes", withExtension: nil),
         userDirectory: URL = ConfigDirectory.themesDirectory,
         fileManager: FileManager = .default) {
        self.builtInDirectory = builtInDirectory
        self.userDirectory = userDirectory
        self.fileManager = fileManager
    }

    /// All theme names, sorted. Reads directory listings only.
    func availableThemes() -> [Entry] {
        var byName: [String: Entry] = [:]
        for entry in entries(in: builtInDirectory, isBuiltIn: true) { byName[entry.name.lowercased()] = entry }
        // User themes win over built-in themes with the same name.
        for entry in entries(in: userDirectory, isBuiltIn: false) { byName[entry.name.lowercased()] = entry }
        return byName.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Loads one theme by name. Throws if the theme does not exist or is invalid.
    func loadTheme(named name: String) throws -> Theme {
        guard let entry = availableThemes().first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            throw ThemeManagerError.notFound(name)
        }
        let text = try String(contentsOf: entry.url, encoding: .utf8)
        return try Theme.parse(yaml: text)
    }

    /// Returns the best usable theme. Never throws.
    ///
    /// Order: the requested theme, the last good theme, the built-in fallback.
    func resolveTheme(named name: String?) -> Theme? {
        lastError = nil
        if let name = name {
            do {
                let theme = try loadTheme(named: name)
                lastGoodTheme = theme
                return theme
            } catch {
                lastError = error
            }
        }
        if let theme = lastGoodTheme { return theme }
        if let theme = try? loadTheme(named: ThemeManager.fallbackName) {
            lastGoodTheme = theme
            return theme
        }
        return nil
    }

    private func entries(in directory: URL?, isBuiltIn: Bool) -> [Entry] {
        guard let directory = directory,
              let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return [] }
        return files
            .filter { ["yaml", "yml"].contains($0.pathExtension.lowercased()) }
            .map { Entry(name: $0.deletingPathExtension().lastPathComponent, url: $0, isBuiltIn: isBuiltIn) }
    }
}

enum ThemeManagerError: Error, Equatable, LocalizedError {
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case let .notFound(name): return "Theme “\(name)” was not found."
        }
    }
}
