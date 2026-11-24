import AppKit

/// Connects the YAML theme to the preview.
///
/// `MPRenderer` asks for a stylesheet URL each time it renders. The answer is
/// nil when `config.yaml` names no theme, so nothing changes for users who do
/// not use themes. When the config folder changes, the service reloads and posts
/// `didChangeNotification`, so open documents re-render.
@objc(MPThemeService)
final class ThemeService: NSObject {
    /// Replaceable so tests can point it at a temporary config folder.
    @objc static var shared = ThemeService()
    /// Posted on the main thread after the config folder changed.
    @objc static let didChangeNotificationName = "MPThemeServiceDidChange"
    static let didChangeNotification = Notification.Name(didChangeNotificationName)

    private let configDirectory: URL
    private let cacheDirectory: URL
    private let manager: ThemeManager
    private let lock = NSLock()

    private var loaded = false
    private var config = AppConfig.default
    private var theme: Theme?
    private var watcher: DirectoryWatcher?
    private var lastResult: (key: String, url: URL)?

    /// Font files in the app and where the preview can load them (tests give their own).
    private let fontFiles: [String]
    private let fontBaseURL: String

    init(configDirectory: URL = ConfigDirectory.url,
         cacheDirectory: URL? = nil,
         manager: ThemeManager? = nil,
         fontFiles: [String]? = nil,
         fontBaseURL: String? = nil) {
        self.configDirectory = configDirectory
        let fontsFolder = Bundle.main.resourceURL?.appendingPathComponent("Fonts")
        self.fontFiles = fontFiles ?? fontsFolder.flatMap { try? FileManager.default.contentsOfDirectory(atPath: $0.path) } ?? []
        self.fontBaseURL = fontBaseURL ?? fontsFolder.map { PreviewURL.previewURL(for: $0).absoluteString + "/" } ?? ""
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cacheDirectory
            ?? caches.appendingPathComponent(Bundle.main.bundleIdentifier ?? "MacDown").appendingPathComponent("Themes")
        self.manager = manager ?? ThemeManager(userDirectory: configDirectory.appendingPathComponent("themes"))
        super.init()
    }

    /// The generated stylesheet for the active theme, or nil if no theme is set.
    @objc func previewStylesheetURL() -> URL? {
        let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return previewStylesheetURL(isDark: isDark)
    }

    func previewStylesheetURL(isDark: Bool) -> URL? {
        lock.lock(); defer { lock.unlock() }
        loadIfNeeded()
        // The theme and the fonts both come from config.yaml. Either, both or neither may be set.
        let themeCSS = theme.map { ThemeCSS.css(for: $0.variant(isDark: isDark), isDark: isDark) } ?? ""
        let fontCSS = FontCSS.css(settings: FontCSS.settings(bodyName: config.fonts.body, codeName: config.fonts.code, files: fontFiles),
                                  files: fontFiles, baseURL: fontBaseURL)
        guard !themeCSS.isEmpty || !fontCSS.isEmpty else { return nil }
        let css = themeCSS + fontCSS
        let key = "\(theme?.name ?? "")|\(isDark)|\(css.count)|\(css.hashValue)"
        if let last = lastResult, last.key == key { return last.url }

        let hash = String(format: "%08x", abs(css.hashValue) & 0xFFFF_FFFF)
        let safeName = (theme?.name ?? "Fonts").map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
        let url = cacheDirectory.appendingPathComponent("\(safeName)-\(isDark ? "dark" : "light")-\(hash).css")
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                try css.write(to: url, atomically: true, encoding: .utf8)
                removeStaleFiles(keeping: url, namePrefix: "\(safeName)-\(isDark ? "dark" : "light")-")
            }
        } catch {
            return nil   // No cache folder: use the base style rather than failing.
        }
        lastResult = (key, url)
        return url
    }

    /// The settings from `config.yaml` (defaults if there is no file or it is broken).
    func currentConfig() -> AppConfig {
        lock.lock(); defer { lock.unlock() }
        loadIfNeeded()
        return config
    }

    /// Reads `config.yaml` and the theme again. Call after the config folder changed.
    func reload() {
        lock.lock()
        loaded = false
        lastResult = nil
        lock.unlock()
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        config = AppConfig.load(from: configDirectory.appendingPathComponent("config.yaml")).config
        if let name = config.theme {
            theme = manager.resolveTheme(named: name)
        } else {
            theme = nil
        }
        startWatchingIfNeeded()
    }

    private func startWatchingIfNeeded() {
        guard watcher == nil, FileManager.default.fileExists(atPath: configDirectory.path) else { return }
        watcher = DirectoryWatcher(root: configDirectory, latency: 0.3, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.reload()
            NotificationCenter.default.post(name: ThemeService.didChangeNotification, object: self)
        }
    }

    private func removeStaleFiles(keeping keep: URL, namePrefix: String) {
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)) ?? []
        // Compare names, not URLs: the system may list /private/var for /var.
        for file in files where file.lastPathComponent != keep.lastPathComponent
                && file.lastPathComponent.hasPrefix(namePrefix) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
