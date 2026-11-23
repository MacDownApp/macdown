import XCTest
@testable import MacDown

final class ThemeCSSTests: XCTestCase {
    private func variant(_ yaml: String) throws -> ThemeVariant {
        try Theme.parse(yaml: yaml).variant(isDark: false)
    }

    private let sample = """
    name: T
    editor: { background: "#fdf6e3", text: "#657b83", line-highlight: "#f5efdc" }
    tokens:
      heading: { color: "#268bd2", bold: true }
      link: { color: "#2aa198" }
      code: { color: "#859900" }
      quote: { color: "#93a1a1", italic: true }
      list: { color: "#cb4b16" }
      keyword: { color: "#859900" }
      comment: { color: "#93a1a1", italic: true }
    preview: { content-width: 700 }
    """

    func testGeneratesPageHeadingLinkAndCodeRules() throws {
        let css = ThemeCSS.css(for: try variant(sample), isDark: false)
        XCTAssertTrue(css.contains("html { color-scheme: light; background: #fdf6e3; }"), css)
        XCTAssertTrue(css.contains("body { background: #fdf6e3; color: #657b83; max-width: 700px; margin-left: auto; margin-right: auto; }"), css)
        XCTAssertTrue(css.contains("body h1, body h2, body h3, body h4, body h5, body h6 { color: #268bd2; font-weight: bold; }"), css)
        XCTAssertTrue(css.contains("body a { color: #2aa198; }"), css)
        XCTAssertTrue(css.contains("body :not(pre) > code { color: #859900; }"), css)
        XCTAssertTrue(css.contains("body blockquote { color: #93a1a1; font-style: italic; }"), css)
        XCTAssertTrue(css.contains("body li::marker { color: #cb4b16; }"), css)
        XCTAssertTrue(css.contains("body pre, body pre code { background: #f5efdc;"), css)
    }

    func testPrismTokensFollowTheTheme() throws {
        let css = ThemeCSS.css(for: try variant(sample), isDark: false)
        XCTAssertTrue(css.contains("body .token.keyword, body .token.atrule"), css)
        XCTAssertTrue(css.contains("body .token.comment, body .token.prolog"), css)
        XCTAssertFalse(css.contains(".token.string"), "Tokens the theme does not define are left alone")
    }

    func testDarkFlagAndNoWidth() throws {
        let css = ThemeCSS.css(for: try variant("name: D\nappearance: dark\neditor: { background: \"#000\", text: \"#fff\" }\n"), isDark: true)
        XCTAssertTrue(css.contains("color-scheme: dark"))
        XCTAssertFalse(css.contains("max-width"))
        XCTAssertTrue(css.contains("body pre, body pre code { background: rgba(255, 255, 255, 0.06);"), css)
    }

    func testOutputIsDeterministic() throws {
        let v = try variant(sample)
        XCTAssertEqual(ThemeCSS.css(for: v, isDark: false), ThemeCSS.css(for: v, isDark: false))
    }

    func testEveryBuiltInThemeProducesCSS() throws {
        let dir = try XCTUnwrap(Bundle(for: ThemeManager.self).url(forResource: "BuiltinThemes", withExtension: nil))
        let manager = ThemeManager(builtInDirectory: dir, userDirectory: dir.appendingPathComponent("none"))
        for entry in manager.availableThemes() {
            let theme = try manager.loadTheme(named: entry.name)
            let css = ThemeCSS.css(for: theme.variant(isDark: theme.appearance == .dark), isDark: theme.appearance == .dark)
            XCTAssertTrue(css.contains("body h1"), entry.name)
            XCTAssertFalse(css.contains("\n\n"), entry.name)
        }
    }
}

final class ThemeServiceTests: XCTestCase {
    private var root: URL!
    private var config: URL!
    private var cache: URL!
    private var builtIn: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("macdown-theme-\(UUID().uuidString)").resolvingSymlinksInPath()
        config = root.appendingPathComponent("config")
        cache = root.appendingPathComponent("cache")
        builtIn = root.appendingPathComponent("builtin")
        for dir in [config!, builtIn!] { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
        try theme("Light One", bg: "#ffffff").write(to: builtIn.appendingPathComponent("Light One.yaml"), atomically: true, encoding: .utf8)
        try theme("GitHub Light", bg: "#fafafa").write(to: builtIn.appendingPathComponent("GitHub Light.yaml"), atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func theme(_ name: String, bg: String) -> String {
        "name: \(name)\neditor: { background: \"\(bg)\", text: \"#111111\" }\ntokens:\n  heading: { color: \"#ff0000\" }\n"
    }

    private func service() -> ThemeService {
        ThemeService(configDirectory: config, cacheDirectory: cache,
                     manager: ThemeManager(builtInDirectory: builtIn, userDirectory: config.appendingPathComponent("themes")))
    }

    private func setConfig(_ text: String) throws {
        try text.write(to: config.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
    }

    func testNoThemeInConfigMeansNoStylesheet() throws {
        XCTAssertNil(service().previewStylesheetURL(isDark: false))
        try setConfig("git:\n  enabled: false\n")
        XCTAssertNil(service().previewStylesheetURL(isDark: false))
    }

    func testConfiguredThemeWritesAStylesheet() throws {
        try setConfig("theme: Light One\n")
        let url = try XCTUnwrap(service().previewStylesheetURL(isDark: false))
        let css = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(css.contains("background: #ffffff"))
        XCTAssertTrue(url.lastPathComponent.hasPrefix("Light-One-light-"), url.lastPathComponent)
    }

    func testSameThemeGivesSameFileAndChangesGiveANewOne() throws {
        try setConfig("theme: Light One\n")
        let s = service()
        let first = try XCTUnwrap(s.previewStylesheetURL(isDark: false))
        XCTAssertEqual(s.previewStylesheetURL(isDark: false), first)

        try FileManager.default.createDirectory(at: config.appendingPathComponent("themes"), withIntermediateDirectories: true)
        try theme("Light One", bg: "#eeeeee").write(to: config.appendingPathComponent("themes/Light One.yaml"),
                                                    atomically: true, encoding: .utf8)
        s.reload()
        let second = try XCTUnwrap(s.previewStylesheetURL(isDark: false))
        XCTAssertNotEqual(first, second, "A changed theme must not reuse the old file (the web view caches by URL)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path), "Old generated files are removed")
        XCTAssertTrue(try String(contentsOf: second, encoding: .utf8).contains("#eeeeee"))
    }

    func testUnknownThemeFallsBackToDefault() throws {
        try setConfig("theme: Does Not Exist\n")
        let url = try XCTUnwrap(service().previewStylesheetURL(isDark: false))
        XCTAssertTrue(try String(contentsOf: url, encoding: .utf8).contains("#fafafa"), "Falls back to GitHub Light")
    }

    func testBrokenConfigGivesNoStylesheetAndNoCrash() throws {
        try setConfig("theme: [unclosed")
        XCTAssertNil(service().previewStylesheetURL(isDark: false))
    }

    func testUnwritableCacheFallsBackToNil() throws {
        try setConfig("theme: Light One\n")
        let blocked = root.appendingPathComponent("blocked")
        try "file, not a folder".write(to: blocked, atomically: true, encoding: .utf8)
        let s = ThemeService(configDirectory: config, cacheDirectory: blocked.appendingPathComponent("sub"),
                             manager: ThemeManager(builtInDirectory: builtIn, userDirectory: config.appendingPathComponent("themes")))
        XCTAssertNil(s.previewStylesheetURL(isDark: false))
    }

    func testChangingTheConfigFolderPostsANotification() throws {
        try setConfig("theme: Light One\n")
        let s = service()
        _ = s.previewStylesheetURL(isDark: false)   // Loads and starts the watcher.
        let posted = expectation(description: "notification")
        posted.assertForOverFulfill = false
        // An early event from the first write can arrive too; wait for the new theme.
        let token = NotificationCenter.default.addObserver(forName: ThemeService.didChangeNotification, object: s, queue: .main) { _ in
            if let url = s.previewStylesheetURL(isDark: false),
               (try? String(contentsOf: url, encoding: .utf8))?.contains("#fafafa") == true { posted.fulfill() }
        }
        defer { NotificationCenter.default.removeObserver(token) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { try? self.setConfig("theme: GitHub Light\n") }
        wait(for: [posted], timeout: 6)
    }
}
