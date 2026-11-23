import XCTest
@testable import MacDown

/// Mermaid and Vega-Lite from Markdown to SVG, in a real web view.
final class DiagramPreviewTests: XCTestCase {
    private final class Stub: NSObject, MPRendererDataSource, MPRendererDelegate, PreviewControllerDelegate {
        var markdown = ""
        var html = ""
        var mermaid = true
        func rendererLoading() -> Bool { false }
        func rendererMarkdown(_ renderer: MPRenderer) -> String { markdown }
        func rendererHTMLTitle(_ renderer: MPRenderer) -> String { "T" }
        func rendererMarkdownOptions(_ renderer: MPRenderer) -> MPMarkdownRenderOptions {
            let o = MPMarkdownRenderOptions(); o.fencedCode = true; o.tables = true; return o
        }
        func rendererStyleName(_ renderer: MPRenderer) -> String { "GitHub2" }
        func rendererHasSyntaxHighlighting(_ renderer: MPRenderer) -> Bool { false }
        func rendererHasMermaid(_ renderer: MPRenderer) -> Bool { mermaid }
        func rendererHasGraphviz(_ renderer: MPRenderer) -> Bool { false }
        func rendererCodeBlockAccesory(_ renderer: MPRenderer) -> MPCodeBlockAccessoryType { .none }
        func rendererHasMathJax(_ renderer: MPRenderer) -> Bool { false }
        func rendererHighlightingThemeName(_ renderer: MPRenderer) -> String { "Tomorrow" }
        func renderer(_ renderer: MPRenderer, didProduceHTMLOutput html: String) { self.html = html }
        func previewDidFinishLoading(_ preview: PreviewController) {}
        func previewMathJaxDidFinish(_ preview: PreviewController) {}
        func preview(_ preview: PreviewController, shouldNavigateTo url: URL) -> Bool { true }
        func previewDidScroll(_ preview: PreviewController) {}
    }

    private var window: NSWindow!
    private var controller: PreviewController!
    private var stub: Stub!
    private var renderer: MPRenderer!
    private var dir: URL!
    private var savedService: ThemeService!

    override func setUpWithError() throws {
        savedService = ThemeService.shared
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("macdown-diagram-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("config"), withIntermediateDirectories: true)
        useConfig(nil)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        window.contentView = container
        let placeholder = NSView(frame: container.bounds)
        container.addSubview(placeholder)
        stub = Stub()
        controller = PreviewController(replacing: placeholder, delegate: stub)
        renderer = MPRenderer()
        renderer.dataSource = stub
        renderer.delegate = stub
    }

    override func tearDown() {
        ThemeService.shared = savedService
        controller.tearDown()
        window.close()
        try? FileManager.default.removeItem(at: dir)
    }

    /// Points the app at a temporary config folder (so tests never read the user's).
    private func useConfig(_ yaml: String?) {
        let config = dir.appendingPathComponent("config")
        let file = config.appendingPathComponent("config.yaml")
        if let yaml = yaml { try? yaml.write(to: file, atomically: true, encoding: .utf8) } else { try? FileManager.default.removeItem(at: file) }
        ThemeService.shared = ThemeService(configDirectory: config, cacheDirectory: dir.appendingPathComponent("cache"))
    }

    private func waitUntil(_ timeout: TimeInterval = 20, _ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let end = Date().addingTimeInterval(timeout)
        while !condition() && Date() < end { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02)) }
        XCTAssertTrue(condition(), "Timed out", file: file, line: line)
    }

    private func js(_ script: String) -> Any? {
        var result: Any?
        var done = false
        controller.webView.evaluateJavaScript(script) { value, _ in result = value; done = true }
        waitUntil { done }
        return result
    }

    /// Renders with the real renderer, shows it, and waits until all diagrams are drawn or failed.
    private func show(_ markdown: String) {
        stub.markdown = markdown
        stub.html = ""
        renderer.parseAndRenderNow()
        waitUntil { !self.stub.html.isEmpty }
        controller.loadHTML(stub.html, baseURL: dir)
        waitUntil { !self.controller.isLoading }
        waitUntil { (self.js("window.MacDownDiagrams ? MacDownDiagrams.pending : -1") as? Int) == 0 }
    }

    private func count(_ selector: String) -> Int { js("document.querySelectorAll('\(selector)').length") as? Int ?? -1 }
    private func errors() -> [String] {
        (js("Array.from(document.querySelectorAll('.macdown-diagram-error')).map(e => e.textContent).join('|')") as? String ?? "")
            .split(separator: "|").map(String.init)
    }

    private let barChart = """
    {"data": {"values": [{"a": "A", "b": 28}, {"a": "B", "b": 55}, {"a": "C", "b": 43}]},
     "mark": "bar", "encoding": {"x": {"field": "a", "type": "nominal"}, "y": {"field": "b", "type": "quantitative"}}}
    """

    // MARK: Laziness

    func testPagesWithoutDiagramsLoadNoLibraries() {
        show("# Plain\n\n```swift\nlet x = 1\n```\n")
        XCTAssertEqual(js("typeof mermaid") as? String, "undefined")
        XCTAssertEqual(js("typeof vega") as? String, "undefined")
        XCTAssertEqual(js("typeof vegaEmbed") as? String, "undefined")
        XCTAssertEqual(js("document.querySelectorAll(\"script[src*='mermaid.min'], script[src*='vega.min'], script[src*='vega-lite.min'], script[src*='vega-embed']\").length") as? Int, 0)
        XCTAssertEqual(count(".macdown-diagram"), 0)
    }

    func testChartLibrariesAreNotLoadedForMermaidOnlyPages() {
        show("```mermaid\ngraph TD; A-->B;\n```\n")
        XCTAssertEqual(js("typeof mermaid") as? String, "object")
        XCTAssertEqual(js("typeof vega") as? String, "undefined")
    }

    // MARK: Mermaid

    func testFlowchartIsDrawn() {
        show("Before\n\n```mermaid\ngraph TD;\n  Start --> Stop;\n```\n\nAfter\n")
        XCTAssertEqual(count(".macdown-diagram-mermaid svg"), 1)
        XCTAssertTrue((js("document.querySelector('.macdown-diagram-mermaid').textContent") as? String ?? "").contains("Start"))
        XCTAssertEqual(count("code.language-mermaid"), 0, "The source block is replaced by the picture")
        XCTAssertTrue((js("document.body.textContent") as? String ?? "").contains("After"))
    }

    func testOtherDiagramTypesWorkFromTheSingleBundledFile() {
        let types = [
            "sequenceDiagram\n  Alice->>Bob: Hello",
            "pie title Pets\n  \"Dogs\" : 4\n  \"Cats\" : 2",
            "classDiagram\n  Animal <|-- Duck",
            "stateDiagram-v2\n  [*] --> Still\n  Still --> [*]",
            "erDiagram\n  CUSTOMER ||--o{ ORDER : places",
            "gantt\n  title T\n  dateFormat YYYY-MM-DD\n  section S\n  Task :a1, 2024-01-01, 3d",
            "journey\n  title Day\n  section Work\n    Code: 5: Me",
            "mindmap\n  root((Idea))\n    Branch",
        ]
        show(types.map { "```mermaid\n\($0)\n```" }.joined(separator: "\n\n"))
        XCTAssertEqual(count(".macdown-diagram-mermaid svg"), types.count, "errors: \(errors())")
        XCTAssertEqual(errors(), [])
    }

    func testInvalidMermaidKeepsTheSourceAndShowsAMessage() {
        show("```mermaid\nthis is not a diagram\n```\n\n```mermaid\ngraph LR; ok-->fine;\n```\n")
        XCTAssertEqual(count(".macdown-diagram-mermaid svg"), 1, "The good diagram still draws")
        XCTAssertEqual(count("code.language-mermaid"), 1, "The broken source stays visible")
        let messages = errors()
        XCTAssertEqual(messages.count, 1)
        XCTAssertTrue(messages[0].hasPrefix("Mermaid:"), messages[0])
        XCTAssertEqual(count("[id^=dmmd]"), 0, "Mermaid's own error picture must be removed")
    }

    func testMermaidCanBeTurnedOff() {
        stub.mermaid = false
        show("```mermaid\ngraph TD; A-->B;\n```\n")
        XCTAssertEqual(count("code.language-mermaid"), 1)
        XCTAssertEqual(js("typeof mermaid") as? String, "undefined")
        XCTAssertFalse(stub.html.contains("mermaid-init.js"))
    }

    func testMermaidFollowsADarkPage() {
        stub.markdown = "```mermaid\ngraph TD; A-->B;\n```\n"
        renderer.parseAndRenderNow()
        waitUntil { !self.stub.html.isEmpty }
        let dark = stub.html.replacingOccurrences(of: "</head>", with: "<style>html,body{background:#111;color:#eee}</style></head>")
        controller.loadHTML(dark, baseURL: dir)
        waitUntil { !self.controller.isLoading }
        waitUntil { (self.js("window.MacDownDiagrams ? MacDownDiagrams.pending : -1") as? Int) == 0 }
        XCTAssertEqual(js("MacDownDiagrams.isDark()") as? Bool, true)
        XCTAssertEqual(count(".macdown-diagram-mermaid svg"), 1)
    }

    func testSecondRenderOfTheSameDiagramWorks() {
        let md = "```mermaid\ngraph TD; A-->B;\n```\n"
        show(md)
        let first = js("document.querySelector('.macdown-diagram-mermaid').textContent") as? String
        show(md)
        XCTAssertEqual(count(".macdown-diagram-mermaid svg"), 1)
        XCTAssertEqual(js("document.querySelector('.macdown-diagram-mermaid').textContent") as? String, first)
    }

    func testManyDiagramsStayQuick() {
        let md = (0..<15).map { "```mermaid\ngraph TD; N\($0)-->M\($0);\n```" }.joined(separator: "\n\n")
        let start = Date()
        show(md)
        XCTAssertEqual(count(".macdown-diagram-mermaid svg"), 15)
        XCTAssertLessThan(Date().timeIntervalSince(start), 10)
    }

    // MARK: Vega-Lite

    func testJSONChartIsDrawn() {
        show("```vega-lite\n\(barChart)\n```\n")
        XCTAssertEqual(count(".macdown-diagram-vega svg"), 1, "errors: \(errors())")
        XCTAssertEqual(count(".macdown-diagram-vega svg .mark-rect path, .macdown-diagram-vega svg .mark-rect rect"), 3)
        XCTAssertEqual(count("code.language-vega-lite"), 0)
        XCTAssertEqual(js("typeof mermaid") as? String, "undefined", "Mermaid must not load for a chart page")
    }

    func testYAMLChartIsDrawn() {
        show("""
        ```vega-lite
        data:
          values:
            - {a: A, b: 28}
            - {a: B, b: 55}
        mark: bar
        encoding:
          x: {field: a, type: nominal}
          y: {field: b, type: quantitative}
        ```
        """)
        XCTAssertEqual(count(".macdown-diagram-vega svg"), 1, "errors: \(errors())")
        XCTAssertEqual(errors(), [])
    }

    func testChartTextUsesThePageColor() {
        show("```vega-lite\n\(barChart)\n```\n")
        let page = js("getComputedStyle(document.body).color") as? String
        let label = js("(document.querySelector('.macdown-diagram-vega svg text') || {}).getAttribute ? document.querySelector('.macdown-diagram-vega svg text').getAttribute('fill') : ''") as? String
        XCTAssertNotNil(page)
        XCTAssertEqual(label, page, "Axis labels follow the page text color")
    }

    func testBrokenSpecsShowMessages() {
        show("```vega-lite\n{ not valid\n```\n\n```vega-lite\n{\"mark\": \"nonsense\"}\n```\n\n```vega-lite\n- just\n- a list\n```\n")
        XCTAssertEqual(count("code.language-vega-lite"), 3, "Sources stay visible")
        let messages = errors()
        XCTAssertEqual(messages.count, 3, "\(messages)")
        XCTAssertTrue(messages.allSatisfy { $0.hasPrefix("Chart:") })
    }

    func testTooMuchInlineDataIsRefused() {
        let values = (0..<100_001).map { "{\"a\":\($0 % 5),\"b\":1}" }.joined(separator: ",")
        show("```vega-lite\n{\"data\":{\"values\":[\(values)]},\"mark\":\"point\",\"encoding\":{\"x\":{\"field\":\"a\",\"type\":\"quantitative\"}}}\n```\n")
        XCTAssertTrue(errors().first?.contains("Too much inline data") ?? false, "\(errors())")
    }

    func testLocalDataFilesLoadAndWebDataIsBlockedByDefault() throws {
        try "[{\"a\":\"X\",\"b\":1},{\"a\":\"Y\",\"b\":2},{\"a\":\"Z\",\"b\":3},{\"a\":\"W\",\"b\":4}]".write(to: dir.appendingPathComponent("data.json"), atomically: true, encoding: .utf8)
        show("""
        ```vega-lite
        {"data": {"url": "data.json"}, "mark": "bar", "encoding": {"x": {"field": "a", "type": "nominal"}, "y": {"field": "b", "type": "quantitative"}}}
        ```

        ```vega-lite
        {"data": {"url": "https://example.com/data.json"}, "mark": "bar", "encoding": {"x": {"field": "a", "type": "nominal"}}}
        ```
        """)
        XCTAssertEqual(count(".macdown-diagram-vega svg"), 1, "errors: \(errors())")
        XCTAssertEqual(count(".macdown-diagram-vega svg .mark-rect path, .macdown-diagram-vega svg .mark-rect rect"), 4, "The local file was read")
        let messages = errors()
        XCTAssertEqual(messages.count, 1)
        XCTAssertTrue(messages[0].contains("turned off"), messages[0])
    }

    func testWebDataCanBeAllowedInConfig() {
        useConfig("charts:\n  vega-lite-remote-data: true\n")
        // Nothing listens here, so the request fails: with the setting on, it must at least be tried.
        show("```vega-lite\n{\"data\": {\"url\": \"http://127.0.0.1:9/none.json\"}, \"mark\": \"bar\"}\n```\n")
        let messages = errors()
        XCTAssertEqual(messages.count, 1, "\(messages)")
        XCTAssertFalse(messages[0].contains("turned off"), "The setting must reach the page: \(messages[0])")
    }

    func testFullVegaSpecs() {
        show("```vega\n{\"width\": 100, \"height\": 100, \"marks\": [{\"type\": \"rect\", \"encode\": {\"enter\": {\"x\": {\"value\": 5}, \"y\": {\"value\": 5}, \"width\": {\"value\": 50}, \"height\": {\"value\": 50}, \"fill\": {\"value\": \"steelblue\"}}}}]}\n```\n")
        XCTAssertEqual(count(".macdown-diagram-vega svg"), 1, "errors: \(errors())")
    }

    // MARK: Both, and export

    func testChartsAndDiagramsOnOnePage() {
        show("```mermaid\ngraph TD; A-->B;\n```\n\n```vega-lite\n\(barChart)\n```\n\nText with `inline code` and a table:\n\n|a|b|\n|-|-|\n|1|2|\n")
        XCTAssertEqual(count(".macdown-diagram svg"), 2, "errors: \(errors())")
        XCTAssertEqual(count("table td"), 2)
    }

    func testExportedHTMLEmbedsLoadersAndUsesPinnedCDN() {
        stub.markdown = "```mermaid\ngraph TD; A-->B;\n```\n"
        renderer.parseAndRenderNow()
        waitUntil { !self.stub.html.isEmpty }
        let html = renderer.htmlForExport(withStyles: true, highlighting: false) ?? ""
        XCTAssertTrue(html.contains("MacDownDiagrams"), "Loaders are embedded")
        XCTAssertTrue(html.contains("cdn.jsdelivr.net/npm/"))
        XCTAssertTrue(html.contains("mermaid@11.17.2/dist/mermaid.min.js"))
        XCTAssertTrue(html.contains("vega-lite@5.23.0/build/vega-lite.min.js"))
        XCTAssertFalse(html.contains("file://"), "An exported file must not point into the app")
        XCTAssertFalse(html.contains("macdown-file"))
        XCTAssertFalse(html.contains("<script type=\"text/javascript\" src="), "No loader may be linked by path")
    }

    func testGraphvizIsGone() {
        XCTAssertNil(Bundle.main.url(forResource: "viz", withExtension: "js", subdirectory: "Extensions"))
        show("```dot\ndigraph G { a -> b }\n```\n")
        XCTAssertEqual(count("code.language-dot"), 1, "Graphviz blocks are shown as code")
    }
}
