import XCTest
@testable import MacDown

/// Checks that a theme from config.yaml reaches the HTML that MPRenderer produces,
/// the same HTML the preview and "Export HTML" use.
final class RendererThemeIntegrationTests: XCTestCase {
    private final class Stub: NSObject, MPRendererDataSource, MPRendererDelegate {
        func rendererLoading() -> Bool { false }
        func rendererMarkdown(_ renderer: MPRenderer) -> String { "# Title\n\n```swift\nlet x = 1\n```\n" }
        func rendererHTMLTitle(_ renderer: MPRenderer) -> String { "Test" }
        func rendererMarkdownOptions(_ renderer: MPRenderer) -> MPMarkdownRenderOptions {
            let o = MPMarkdownRenderOptions(); o.fencedCode = true; return o
        }
        func rendererStyleName(_ renderer: MPRenderer) -> String { "GitHub2" }
        func rendererHasSyntaxHighlighting(_ renderer: MPRenderer) -> Bool { false }
        func rendererHasMermaid(_ renderer: MPRenderer) -> Bool { false }
        func rendererHasGraphviz(_ renderer: MPRenderer) -> Bool { false }
        func rendererCodeBlockAccesory(_ renderer: MPRenderer) -> MPCodeBlockAccessoryType { .none }
        func rendererHasMathJax(_ renderer: MPRenderer) -> Bool { false }
        func rendererHighlightingThemeName(_ renderer: MPRenderer) -> String { "Tomorrow" }
        func renderer(_ renderer: MPRenderer, didProduceHTMLOutput html: String) {}
    }

    private var original: ThemeService!
    private var root: URL!

    override func setUpWithError() throws {
        original = ThemeService.shared
        root = FileManager.default.temporaryDirectory.appendingPathComponent("macdown-int-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root.appendingPathComponent("config"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        ThemeService.shared = original
        try? FileManager.default.removeItem(at: root)
    }

    private func exportHTML(configuredTheme: String?) throws -> String {
        let config = root.appendingPathComponent("config")
        if let theme = configuredTheme {
            try "theme: \(theme)\n".write(to: config.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        }
        ThemeService.shared = ThemeService(configDirectory: config, cacheDirectory: root.appendingPathComponent("cache"))

        let stub = Stub()
        let renderer = MPRenderer()
        renderer.dataSource = stub
        renderer.delegate = stub
        renderer.parseAndRenderNow()
        // Parsing runs on a background queue and delivers to the main queue.
        let done = expectation(description: "rendered")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { done.fulfill() }
        wait(for: [done], timeout: 5)
        return renderer.htmlForExport(withStyles: true, highlighting: false)
    }

    func testConfiguredThemeIsEmbeddedInExportedHTML() throws {
        let html = try exportHTML(configuredTheme: "Dracula")
        XCTAssertTrue(html.contains("Generated from the MacDown theme"), "Theme CSS missing from the page")
        XCTAssertTrue(html.contains("background: #282a36"), "Dracula background missing")
        XCTAssertTrue(html.contains("<h1 id=\"toc_0\">Title</h1>"))
        XCTAssertTrue(html.contains("language-swift"))
    }

    func testNoThemeLeavesThePageUnchanged() throws {
        let html = try exportHTML(configuredTheme: nil)
        XCTAssertFalse(html.contains("Generated from the MacDown theme"))
        XCTAssertTrue(html.contains("<h1 id=\"toc_0\">Title</h1>"))
    }

    func testThemeComesAfterTheBaseStyle() throws {
        let html = try exportHTML(configuredTheme: "Nord")
        let theme = try XCTUnwrap(html.range(of: "Generated from the MacDown theme"))
        // The exported page embeds each stylesheet in its own <style> block. The base
        // style is first, so at least one block must come before the theme's.
        let before = html[html.startIndex..<theme.lowerBound]
        XCTAssertGreaterThanOrEqual(before.components(separatedBy: "<style").count - 1, 2,
                                    "Expected the base style before the theme")
    }
}
