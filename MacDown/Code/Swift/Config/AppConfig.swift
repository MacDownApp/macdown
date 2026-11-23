import Foundation
import Yams

/// Typed view of `config.yaml`.
///
/// Every key is optional in the file. Missing keys use the defaults below, so
/// an empty or missing file is valid. Unknown keys are ignored.
struct AppConfig: Equatable {
    enum Interface: String, Equatable {
        case classic
        case modern
    }

    struct Editor: Equatable {
        var ligatures = true
        var spellCheck = true
        var multiCursor = true
    }

    struct Git: Equatable {
        var enabled = true
    }

    struct Lint: Equatable {
        var enabled = false
        /// Rule names. Empty means "use the default rule set".
        var rules: [String] = []
    }

    struct Charts: Equatable {
        /// Allow Vega-Lite `data.url` values that use http(s).
        var vegaLiteRemoteData = false
    }

    var interface = Interface.classic
    var theme: String?
    var editor = Editor()
    var git = Git()
    var lint = Lint()
    var charts = Charts()

    static let `default` = AppConfig()
}

// MARK: - Loading

extension AppConfig {
    struct LoadResult {
        var config: AppConfig
        /// Set when the file exists but could not be read or parsed. The
        /// config is then the default one.
        var error: Error?
    }

    /// Reads a config file. Never throws and never crashes: a missing file is
    /// the default config, and a broken file is the default config plus `error`.
    static func load(from url: URL = ConfigDirectory.configFile) -> LoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return LoadResult(config: .default, error: nil)
        }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            return LoadResult(config: try parse(text), error: nil)
        } catch {
            return LoadResult(config: .default, error: error)
        }
    }

    static func parse(_ yaml: String) throws -> AppConfig {
        guard let root = try Yams.load(yaml: yaml) else { return .default }
        guard let dict = root as? [String: Any] else {
            throw ConfigError.notAMapping
        }
        var config = AppConfig()

        if let value = dict["interface"] {
            guard let text = value as? String, let interface = Interface(rawValue: text.lowercased()) else {
                throw ConfigError.invalidValue(key: "interface", expected: "classic or modern")
            }
            config.interface = interface
        }
        if let value = dict["theme"] {
            guard let text = value as? String else {
                throw ConfigError.invalidValue(key: "theme", expected: "a theme name")
            }
            config.theme = text
        }
        if let section = try mapping(dict["editor"], key: "editor") {
            try setBool(&config.editor.ligatures, section, "ligatures", parent: "editor")
            try setBool(&config.editor.spellCheck, section, "spell-check", parent: "editor")
            try setBool(&config.editor.multiCursor, section, "multi-cursor", parent: "editor")
        }
        if let section = try mapping(dict["git"], key: "git") {
            try setBool(&config.git.enabled, section, "enabled", parent: "git")
        }
        if let section = try mapping(dict["lint"], key: "lint") {
            try setBool(&config.lint.enabled, section, "enabled", parent: "lint")
            if let rules = section["rules"] {
                guard let list = rules as? [String] else {
                    throw ConfigError.invalidValue(key: "lint.rules", expected: "a list of rule names")
                }
                config.lint.rules = list
            }
        }
        if let section = try mapping(dict["charts"], key: "charts") {
            try setBool(&config.charts.vegaLiteRemoteData, section, "vega-lite-remote-data", parent: "charts")
        }
        return config
    }

    private static func mapping(_ value: Any?, key: String) throws -> [String: Any]? {
        guard let value = value else { return nil }
        guard let dict = value as? [String: Any] else {
            throw ConfigError.invalidValue(key: key, expected: "a mapping")
        }
        return dict
    }

    private static func setBool(_ target: inout Bool, _ section: [String: Any], _ key: String, parent: String) throws {
        guard let value = section[key] else { return }
        guard let flag = value as? Bool else {
            throw ConfigError.invalidValue(key: "\(parent).\(key)", expected: "true or false")
        }
        target = flag
    }
}

enum ConfigError: Error, Equatable, LocalizedError {
    case notAMapping
    case invalidValue(key: String, expected: String)

    var errorDescription: String? {
        switch self {
        case .notAMapping:
            return "The config file must contain key/value pairs at the top level."
        case let .invalidValue(key, expected):
            return "Invalid value for “\(key)”. Expected \(expected)."
        }
    }
}
