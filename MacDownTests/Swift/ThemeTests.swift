import XCTest
@testable import MacDown

final class ThemeColorTests: XCTestCase {
    func testParsesSixDigitHex() throws {
        let color = try XCTUnwrap(ThemeColor(hex: "#ff8000"))
        XCTAssertEqual(color.red, 1, accuracy: 0.001)
        XCTAssertEqual(color.green, 128.0 / 255, accuracy: 0.001)
        XCTAssertEqual(color.blue, 0, accuracy: 0.001)
        XCTAssertEqual(color.alpha, 1)
    }

    func testParsesShortAndAlphaHex() throws {
        XCTAssertEqual(ThemeColor(hex: "#fff"), ThemeColor(hex: "#ffffff"))
        let color = try XCTUnwrap(ThemeColor(hex: "#00000080"))
        XCTAssertEqual(color.alpha, 128.0 / 255, accuracy: 0.001)
    }

    func testRejectsBadInput() {
        XCTAssertNil(ThemeColor(hex: "ffffff"))
        XCTAssertNil(ThemeColor(hex: "#ggg"))
        XCTAssertNil(ThemeColor(hex: "#12345"))
        XCTAssertNil(ThemeColor(hex: ""))
    }

    func testCSSString() {
        XCTAssertEqual(ThemeColor(hex: "#2E3440")?.cssString, "#2e3440")
        XCTAssertEqual(ThemeColor(hex: "#00000080")?.cssString, "rgba(0, 0, 0, 0.502)")
    }
}

final class ThemeParsingTests: XCTestCase {
    private let single = """
    name: Test
    appearance: dark
    editor:
      background: "#000000"
      text: "#ffffff"
    tokens:
      heading: { color: "#ff0000", bold: true }
      comment: { color: "#888888", italic: true }
      strong: { weight: bold }
    preview:
      content-width: 700
    """

    func testParsesSingleAppearanceTheme() throws {
        let theme = try Theme.parse(yaml: single)
        XCTAssertEqual(theme.name, "Test")
        XCTAssertEqual(theme.appearance, .dark)
        let variant = theme.variant(isDark: false) // single-appearance: always its only variant
        XCTAssertEqual(variant, theme.variant(isDark: true))
        XCTAssertEqual(variant.tokens["heading"]?.bold, true)
        XCTAssertEqual(variant.tokens["comment"]?.italic, true)
        XCTAssertEqual(variant.tokens["strong"]?.bold, true)
        XCTAssertEqual(variant.preview.contentWidth, 700)
    }

    func testDefaultsDerivedFromEditorColors() throws {
        let variant = try Theme.parse(yaml: single).variant(isDark: true)
        XCTAssertEqual(variant.editor.caret, variant.editor.text)
        XCTAssertEqual(variant.editor.selection.alpha, 0.2, accuracy: 0.001)
        XCTAssertEqual(variant.preview.background, variant.editor.background)
        XCTAssertNil(variant.editor.lineHighlight)
    }

    func testBothAppearancesPickByMode() throws {
        let yaml = """
        name: Dual
        appearance: both
        light:
          editor: { background: "#ffffff", text: "#000000" }
        dark:
          editor: { background: "#000000", text: "#ffffff" }
        """
        let theme = try Theme.parse(yaml: yaml)
        XCTAssertEqual(theme.variant(isDark: false).editor.background, ThemeColor(hex: "#ffffff"))
        XCTAssertEqual(theme.variant(isDark: true).editor.background, ThemeColor(hex: "#000000"))
    }

    func testErrors() {
        XCTAssertThrowsError(try Theme.parse(yaml: "")) { XCTAssertEqual($0 as? ThemeError, .notAMapping) }
        XCTAssertThrowsError(try Theme.parse(yaml: "appearance: light\n")) {
            XCTAssertEqual($0 as? ThemeError, .missing("name"))
        }
        XCTAssertThrowsError(try Theme.parse(yaml: "name: X\n")) {
            XCTAssertEqual($0 as? ThemeError, .missing("editor"))
        }
        XCTAssertThrowsError(try Theme.parse(yaml: "name: X\nappearance: neon\n"))
        XCTAssertThrowsError(try Theme.parse(yaml: "name: X\neditor: { background: red, text: \"#000000\" }\n"))
        XCTAssertThrowsError(try Theme.parse(yaml: "name: X\nappearance: both\nlight: {}\n"))
        XCTAssertThrowsError(try Theme.parse(yaml: "name: X\neditor: { background: \"#000\", text: \"#fff\" }\npreview: { content-width: -1 }\n"))
    }

    /// Unquoted colors start a YAML comment, so the key is missing. The user
    /// must get a clear error and not a crash.
    func testUnquotedColorGivesError() {
        XCTAssertThrowsError(try Theme.parse(yaml: "name: X\neditor:\n  background: #000000\n  text: \"#fff\"\n"))
    }
}

final class ThemeManagerTests: XCTestCase {
    private var root: URL!
    private var builtIn: URL!
    private var user: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        builtIn = root.appendingPathComponent("builtin")
        user = root.appendingPathComponent("user")
        try FileManager.default.createDirectory(at: builtIn, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ dir: URL, _ file: String, name: String, background: String = "#ffffff") throws {
        let yaml = "name: \(name)\neditor: { background: \"\(background)\", text: \"#000000\" }\n"
        try yaml.write(to: dir.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }

    private func manager() -> ThemeManager { ThemeManager(builtInDirectory: builtIn, userDirectory: user) }

    func testListsBuiltInAndUserThemesSorted() throws {
        try write(builtIn, "Zed.yaml", name: "Zed")
        try write(builtIn, "Alpha.yaml", name: "Alpha")
        try write(user, "Mine.yml", name: "Mine")
        try "ignore".write(to: user.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
        XCTAssertEqual(manager().availableThemes().map(\.name), ["Alpha", "Mine", "Zed"])
    }

    func testUserThemeOverridesBuiltInWithSameName() throws {
        try write(builtIn, "Nord.yaml", name: "Nord", background: "#111111")
        try write(user, "Nord.yaml", name: "Nord", background: "#222222")
        let themes = manager().availableThemes()
        XCTAssertEqual(themes.count, 1)
        XCTAssertFalse(themes[0].isBuiltIn)
        let theme = try manager().loadTheme(named: "nord")
        XCTAssertEqual(theme.variant(isDark: false).editor.background, ThemeColor(hex: "#222222"))
    }

    func testMissingThemeThrows() {
        XCTAssertThrowsError(try manager().loadTheme(named: "Nope")) {
            XCTAssertEqual($0 as? ThemeManagerError, .notFound("Nope"))
        }
    }

    func testBrokenUserThemeFallsBackToLastGoodTheme() throws {
        try write(builtIn, "GitHub Light.yaml", name: "GitHub Light")
        try write(user, "Mine.yaml", name: "Mine", background: "#123456")
        let m = manager()
        XCTAssertEqual(m.resolveTheme(named: "Mine")?.name, "Mine")

        try "name: Mine\neditor: [".write(to: user.appendingPathComponent("Mine.yaml"), atomically: true, encoding: .utf8)
        XCTAssertEqual(m.resolveTheme(named: "Mine")?.name, "Mine") // last good theme kept
        XCTAssertNotNil(m.lastError)
    }

    func testResolveFallsBackToBuiltInDefault() throws {
        try write(builtIn, "GitHub Light.yaml", name: "GitHub Light")
        let m = manager()
        XCTAssertEqual(m.resolveTheme(named: "Missing")?.name, "GitHub Light")
        XCTAssertNotNil(m.lastError)
        XCTAssertEqual(m.resolveTheme(named: nil)?.name, "GitHub Light")
        XCTAssertNil(m.lastError)
    }

    func testResolveReturnsNilWhenNothingIsAvailable() {
        XCTAssertNil(manager().resolveTheme(named: "Anything"))
    }

    func testAllBundledThemesParse() throws {
        let bundled = Bundle(for: ThemeManager.self).url(forResource: "BuiltinThemes", withExtension: nil)
        let m = ThemeManager(builtInDirectory: try XCTUnwrap(bundled), userDirectory: user)
        let themes = m.availableThemes()
        XCTAssertGreaterThanOrEqual(themes.count, 9)
        XCTAssertTrue(themes.contains { $0.name == ThemeManager.fallbackName })
        for entry in themes {
            XCTAssertNoThrow(try m.loadTheme(named: entry.name), "Theme \(entry.name) failed to parse")
        }
    }
}
