import XCTest
@testable import MacDown

final class FontConfigTests: XCTestCase {
    func testFontsSectionInConfig() throws {
        let config = try AppConfig.parse("fonts:\n  body: Georgia\n  code: \"Cartograph CF Nerd Font\"\n")
        XCTAssertEqual(config.fonts.body, "Georgia")
        XCTAssertEqual(config.fonts.code, "Cartograph CF Nerd Font")
        XCTAssertNil(try AppConfig.parse("theme: Nord\n").fonts.body)
        XCTAssertEqual(try AppConfig.parse("fonts:\n  code: Fira Code\n").fonts, AppConfig.Fonts(body: nil, code: "Fira Code"))
        XCTAssertThrowsError(try AppConfig.parse("fonts:\n  body: [a, b]\n"))
        XCTAssertThrowsError(try AppConfig.parse("fonts: 3\n"))
    }

    func testAppBundleShipsTheFonts() throws {
        let folder = try XCTUnwrap(Bundle.main.resourceURL?.appendingPathComponent("Fonts"), "Fonts folder missing from the app")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        for style in ["Regular", "Bold", "Italic", "BoldItalic"] {
            XCTAssertTrue(files.contains("JetBrainsMonoNerdFont-\(style).ttf"), "JetBrains \(style) missing")
        }
        XCTAssertTrue(files.contains("JetBrainsMono-OFL.txt"), "The license must ship with the font")
        // The app registers them for itself (Info.plist ATSApplicationFontsPath), so they appear in font menus.
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "ATSApplicationFontsPath") as? String, "Fonts")
    }

    // MARK: ThemeService with fonts

    private var dir: URL!
    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("macdown-font-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("config"), withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func service(_ yaml: String, files: [String] = ["JetBrainsMonoNerdFont-Regular.ttf", "JetBrainsMonoNerdFont-Bold.ttf"]) throws -> ThemeService {
        try yaml.write(to: dir.appendingPathComponent("config/config.yaml"), atomically: true, encoding: .utf8)
        return ThemeService(configDirectory: dir.appendingPathComponent("config"), cacheDirectory: dir.appendingPathComponent("cache"),
                            fontFiles: files, fontBaseURL: "macdown-file:///App/Fonts/")
    }

    func testFontsAloneProduceAStylesheet() throws {
        let url = try XCTUnwrap(service("fonts:\n  code: JetBrains Mono Nerd Font\n").previewStylesheetURL(isDark: false))
        let css = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(css.contains("@font-face { font-family: \"MD JetBrains Mono NF\"; src: url(\"macdown-file:///App/Fonts/JetBrainsMonoNerdFont-Regular.ttf\")"), css)
        XCTAssertTrue(css.contains("html body code"), css)
        XCTAssertFalse(css.contains("color-scheme"), "No theme was chosen")
        XCTAssertTrue(url.lastPathComponent.hasPrefix("Fonts-"), url.lastPathComponent)
    }

    func testThemeAndFontsTogether() throws {
        let builtIn = try XCTUnwrap(Bundle.main.url(forResource: "BuiltinThemes", withExtension: nil))
        try "theme: Ayu Mirage\nfonts:\n  body: Georgia\n".write(to: dir.appendingPathComponent("config/config.yaml"), atomically: true, encoding: .utf8)
        let s = ThemeService(configDirectory: dir.appendingPathComponent("config"), cacheDirectory: dir.appendingPathComponent("cache"),
                             manager: ThemeManager(builtInDirectory: builtIn, userDirectory: dir.appendingPathComponent("themes")),
                             fontFiles: [], fontBaseURL: "macdown-file:///App/Fonts/")
        let css = try String(contentsOf: try XCTUnwrap(s.previewStylesheetURL(isDark: false)), encoding: .utf8)
        XCTAssertTrue(css.contains("#1f2430"), "Ayu Mirage background")
        XCTAssertTrue(css.contains("html body { font-family: Georgia"), css)
    }

    func testNoFontsAndNoThemeMeansNoStylesheet() throws {
        XCTAssertNil(try service("git:\n  enabled: false\n").previewStylesheetURL(isDark: false))
        XCTAssertNil(try service("fonts:\n  body: System (SF Pro)\n").previewStylesheetURL(isDark: false), "The default font needs no rule")
    }

    func testChangingTheFontMakesANewFile() throws {
        let s = try service("fonts:\n  body: Georgia\n")
        let first = try XCTUnwrap(s.previewStylesheetURL(isDark: false))
        try "fonts:\n  body: Palatino\n".write(to: dir.appendingPathComponent("config/config.yaml"), atomically: true, encoding: .utf8)
        s.reload()
        let second = try XCTUnwrap(s.previewStylesheetURL(isDark: false))
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(try String(contentsOf: second, encoding: .utf8).contains("Palatino"))
    }
}
