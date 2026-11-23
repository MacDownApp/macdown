import XCTest
@testable import MacDown

final class AppConfigTests: XCTestCase {
    func testEmptyFileUsesDefaults() throws {
        XCTAssertEqual(try AppConfig.parse(""), .default)
    }

    func testDefaultsMatchThePlan() {
        let config = AppConfig.default
        XCTAssertEqual(config.interface, .classic)
        XCTAssertTrue(config.editor.ligatures)
        XCTAssertTrue(config.editor.spellCheck)
        XCTAssertTrue(config.editor.multiCursor)
        XCTAssertTrue(config.git.enabled)
        XCTAssertFalse(config.lint.enabled)
        XCTAssertFalse(config.charts.vegaLiteRemoteData)
    }

    func testParsesAllKeys() throws {
        let yaml = """
        interface: modern
        theme: Nord
        editor:
          ligatures: false
          spell-check: false
          multi-cursor: false
        git:
          enabled: false
        lint:
          enabled: true
          rules: [heading-increment, no-trailing-spaces]
        charts:
          vega-lite-remote-data: true
        """
        let config = try AppConfig.parse(yaml)
        XCTAssertEqual(config.interface, .modern)
        XCTAssertEqual(config.theme, "Nord")
        XCTAssertFalse(config.editor.ligatures)
        XCTAssertFalse(config.editor.spellCheck)
        XCTAssertFalse(config.editor.multiCursor)
        XCTAssertFalse(config.git.enabled)
        XCTAssertTrue(config.lint.enabled)
        XCTAssertEqual(config.lint.rules, ["heading-increment", "no-trailing-spaces"])
        XCTAssertTrue(config.charts.vegaLiteRemoteData)
    }

    func testPartialFileKeepsOtherDefaults() throws {
        let config = try AppConfig.parse("git:\n  enabled: false\n")
        XCTAssertFalse(config.git.enabled)
        XCTAssertTrue(config.editor.ligatures)
    }

    func testUnknownKeysAreIgnored() throws {
        XCTAssertEqual(try AppConfig.parse("future-feature: 1\n"), .default)
    }

    func testInvalidValuesThrow() {
        XCTAssertThrowsError(try AppConfig.parse("interface: neon"))
        XCTAssertThrowsError(try AppConfig.parse("editor:\n  ligatures: maybe\n"))
        XCTAssertThrowsError(try AppConfig.parse("- just\n- a list\n"))
        XCTAssertThrowsError(try AppConfig.parse("lint:\n  rules: 5\n"))
    }

    func testMalformedYamlThrows() {
        XCTAssertThrowsError(try AppConfig.parse("editor: [unclosed"))
    }

    func testMissingFileIsDefaultWithoutError() {
        let url = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)/config.yaml")
        let result = AppConfig.load(from: url)
        XCTAssertEqual(result.config, .default)
        XCTAssertNil(result.error)
    }

    func testBrokenFileFallsBackToDefaultAndReportsError() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("config.yaml")
        try "interface: [".write(to: file, atomically: true, encoding: .utf8)

        let result = AppConfig.load(from: file)
        XCTAssertEqual(result.config, .default)
        XCTAssertNotNil(result.error)
    }
}
