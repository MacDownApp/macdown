import Foundation

/// Location of the user configuration directory (`~/.config/macdown`).
///
/// The directory can be overridden with the `MACDOWN_CONFIG_DIR` environment
/// variable. Tests use this to stay away from the real user directory.
enum ConfigDirectory {
    static var url: URL {
        if let override = ProcessInfo.processInfo.environment["MACDOWN_CONFIG_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("macdown", isDirectory: true)
    }

    static var configFile: URL { url.appendingPathComponent("config.yaml") }
    static var themesDirectory: URL { url.appendingPathComponent("themes", isDirectory: true) }
    static var fontsDirectory: URL { url.appendingPathComponent("fonts", isDirectory: true) }
}
