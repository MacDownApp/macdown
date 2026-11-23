import XCTest
@testable import MacDown

/// Math from Markdown to pixels: engine, KaTeX loader, bundled KaTeX and fonts, in a real web view.
final class MathPreviewTests: XCTestCase {
    private final class Stub: NSObject, MPRendererDataSource, MPRendererDelegate, PreviewControllerDelegate {
        var markdown = ""
        var html = ""
        var mathDone = 0
        var finished = 0
        func rendererLoading() -> Bool { false }
        func rendererMarkdown(_ renderer: MPRenderer) -> String { markdown }
        func rendererHTMLTitle(_ renderer: MPRenderer) -> String { "T" }
        func rendererMarkdownOptions(_ renderer: MPRenderer) -> MPMarkdownRenderOptions {
            let o = MPMarkdownRenderOptions(); o.fencedCode = true; o.math = true; o.mathInlineDollar = true; return o
        }
        func rendererStyleName(_ renderer: MPRenderer) -> String { "GitHub2" }
        func rendererHasSyntaxHighlighting(_ renderer: MPRenderer) -> Bool { false }
        func rendererHasMermaid(_ renderer: MPRenderer) -> Bool { false }
        func rendererHasGraphviz(_ renderer: MPRenderer) -> Bool { false }
        func rendererCodeBlockAccesory(_ renderer: MPRenderer) -> MPCodeBlockAccessoryType { .none }
        func rendererHasMathJax(_ renderer: MPRenderer) -> Bool { true }   // The "math" preference.
        func rendererHighlightingThemeName(_ renderer: MPRenderer) -> String { "Tomorrow" }
        func renderer(_ renderer: MPRenderer, didProduceHTMLOutput html: String) { self.html = html }
        func previewDidFinishLoading(_ preview: PreviewController) { finished += 1 }
        func previewMathJaxDidFinish(_ preview: PreviewController) { mathDone += 1 }
        func preview(_ preview: PreviewController, shouldNavigateTo url: URL) -> Bool { true }
        func previewDidScroll(_ preview: PreviewController) {}
    }

    private var window: NSWindow!
    private var controller: PreviewController!
    private var stub: Stub!
    private var renderer: MPRenderer!

    override func setUpWithError() throws {
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
        controller.tearDown()
        window.close()
    }

    private func waitUntil(_ timeout: TimeInterval = 10, _ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
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

    /// Renders Markdown with the real renderer and shows it in the preview; waits for the math signal.
    private func show(_ markdown: String) {
        stub.markdown = markdown
        stub.html = ""
        renderer.parseAndRenderNow()
        waitUntil { !self.stub.html.isEmpty }
        let before = stub.mathDone
        controller.loadHTML(stub.html, baseURL: FileManager.default.temporaryDirectory)
        waitUntil { self.stub.mathDone > before }
    }

    func testInlineAndDisplayMathAreTypeset() {
        show("Inline $a^2 + b^2 = c^2$ and \\(x_i\\).\n\n$$\n\\int_0^1 x\\,dx = \\frac12\n$$\n\n\\[ E = mc^2 \\]\n")
        XCTAssertEqual(js("document.querySelectorAll('.katex').length") as? Int, 4)
        XCTAssertEqual(js("document.querySelectorAll('.katex-display').length") as? Int, 2)
        XCTAssertEqual(js("document.querySelector('.katex-mathml annotation').textContent") as? String, "a^2 + b^2 = c^2")
        XCTAssertEqual(js("document.body.textContent.indexOf('\\\\(')") as? Int, -1, "No raw delimiters may be left")
    }

    func testBundledFontsLoadOffline() {
        show("$x$")
        waitUntil { (self.js("Array.from(document.fonts).some(f => f.family.indexOf('KaTeX') === 0 && f.status === 'loaded')") as? Bool) == true }
        XCTAssertEqual(js("Array.from(document.fonts).some(f => f.status === 'error')") as? Bool, false)
        XCTAssertFalse(stub.html.contains("http"), "The preview must not need the network: \(stub.html.prefix(300))")
    }

    func testPageWithoutMathNeverLoadsKaTeXButStillSignals() {
        show("# Just text\n\nNo formulas, only $5 and $10 and `\\(code\\)`.\n")
        XCTAssertEqual(js("typeof katex") as? String, "undefined", "KaTeX must be lazy")
        XCTAssertEqual(js("document.querySelectorAll('link[href*=katex]').length") as? Int, 0)
        XCTAssertEqual(stub.mathDone, 1)
        XCTAssertTrue((js("document.body.textContent") as? String ?? "").contains("$5 and $10"))
    }

    func testCurrencyAndCodeAreNotMath() {
        show("Costs $5 and $10 total. Real: $x$.\n\nInline `\\(not math\\)` and\n\n```\n\\[ also not \\]\n$y$\n```\n")
        XCTAssertEqual(js("document.querySelectorAll('.katex').length") as? Int, 1)
        XCTAssertTrue((js("document.querySelector('code').textContent") as? String ?? "") == "\\(not math\\)")
        XCTAssertTrue((js("document.querySelector('pre code').textContent") as? String ?? "").contains("\\[ also not \\]"))
    }

    func testInvalidTeXShowsAnErrorAndDoesNotBreakThePage() {
        show("Bad \\(\\notacommand\\) here and good \\(y\\).\n")
        XCTAssertEqual(js("document.querySelectorAll('.katex').length") as? Int, 2, "Both formulas are drawn")
        XCTAssertEqual(js("Array.from(document.querySelectorAll('.katex *')).some(e => getComputedStyle(e).color === 'rgb(204, 0, 0)')") as? Bool, true,
                       "The unknown command is shown in KaTeX's error color")
        XCTAssertEqual(stub.mathDone, 1)
    }

    func testUnbalancedBracesLeaveTheTextAsIsAndStillSignal() {
        // KaTeX's auto-render stops at math it cannot delimit; the page must still finish loading.
        show("Broken \\(\\frac{\\) text\n")
        XCTAssertEqual(stub.mathDone, 1)
        XCTAssertTrue((js("document.body.textContent") as? String ?? "").contains("Broken"))
    }

    func testMathNextToMarkdownMarkupAndHtmlCharacters() {
        show("**bold** and $a<b$ and $x_1 + y_2$ and ==$z$==\n")
        XCTAssertEqual(js("document.querySelectorAll('.katex').length") as? Int, 3)
        XCTAssertEqual(js("document.querySelector('strong').textContent") as? String, "bold")
        XCTAssertEqual(js("document.querySelectorAll('.katex-mathml annotation')[0].textContent") as? String, "a<b")
    }

    func testLargeAmountOfMathStaysFast() {
        let lines = (0..<500).map { "Line \($0): $x_{\($0)}^2 + \\frac{1}{\($0 + 1)}$" }.joined(separator: "\n\n")
        let start = Date()
        show(lines)
        XCTAssertEqual(js("document.querySelectorAll('.katex').length") as? Int, 500)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5.0)
    }

    func testExportedHTMLUsesPinnedCDNAndNoAppPaths() {
        stub.markdown = "$x$"
        renderer.parseAndRenderNow()
        waitUntil { !self.stub.html.isEmpty }
        let html = renderer.htmlForExport(withStyles: true, highlighting: false) ?? ""
        XCTAssertTrue(html.contains("https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css"))
        XCTAssertTrue(html.contains("https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"))
        XCTAssertTrue(html.contains("https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"))
        XCTAssertTrue(html.contains("renderMathInElement"), "The export init script must be embedded")
        XCTAssertFalse(html.contains("file://"), "An exported file must not point into the app")
        XCTAssertFalse(html.contains("katex-init.js"))
    }

    func testNoMathPreferenceMeansNoMathScripts() {
        final class NoMath: NSObject, MPRendererDelegate, MPRendererDataSource {
            func rendererLoading() -> Bool { false }
            func rendererMarkdown(_ r: MPRenderer) -> String { "$x$" }
            func rendererHTMLTitle(_ r: MPRenderer) -> String { "" }
            func rendererMarkdownOptions(_ r: MPRenderer) -> MPMarkdownRenderOptions { MPMarkdownRenderOptions() }
            func rendererStyleName(_ r: MPRenderer) -> String { "GitHub2" }
            func rendererHasSyntaxHighlighting(_ r: MPRenderer) -> Bool { false }
            func rendererHasMermaid(_ r: MPRenderer) -> Bool { false }
            func rendererHasGraphviz(_ r: MPRenderer) -> Bool { false }
            func rendererCodeBlockAccesory(_ r: MPRenderer) -> MPCodeBlockAccessoryType { .none }
            func rendererHasMathJax(_ r: MPRenderer) -> Bool { false }
            func rendererHighlightingThemeName(_ r: MPRenderer) -> String { "Tomorrow" }
            func renderer(_ r: MPRenderer, didProduceHTMLOutput html: String) {}
        }
        let other = NoMath()
        let r = MPRenderer()
        r.dataSource = other
        r.delegate = other
        r.parseAndRenderNow()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        XCTAssertFalse((r.htmlForExport(withStyles: true, highlighting: false) ?? "").lowercased().contains("katex"))
    }
}
