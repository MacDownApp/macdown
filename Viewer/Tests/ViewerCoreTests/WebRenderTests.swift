import XCTest
import WebKit
@testable import ViewerCore

/// Whole pipeline in a real web view: note -> HTML page -> md:// files -> KaTeX, Mermaid, Prism.
final class WebRenderTests: XCTestCase {
    private var web: WKWebView!
    private var root: URL!      // The fake "app bundle".
    private var vault: URL!
    private var navigation: Navigation!

    final class Navigation: NSObject, WKNavigationDelegate {
        var finished = 0
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finished += 1 }
    }

    override func setUpWithError() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("viewer-web-\(UUID().uuidString)").resolvingSymlinksInPath()
        root = tmp.appendingPathComponent("app")
        vault = tmp.appendingPathComponent("vault")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: vault.appendingPathComponent("img"), withIntermediateDirectories: true)
        // The same layout the iPad app bundle has.
        for (name, source) in [("KaTeX", "MacDown/Resources/KaTeX"), ("Diagrams", "MacDown/Resources/Diagrams"),
                               ("components", "Dependency/prism/components"),
                               ("prism-autoloader.min.js", "Dependency/prism/plugins/autoloader/prism-autoloader.min.js")] {
            try FileManager.default.createSymbolicLink(at: root.appendingPathComponent(name), withDestinationURL: repo.appendingPathComponent(source))
        }
        // A real PNG in the vault.
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
        try png.write(to: vault.appendingPathComponent("img/pic.png"))

        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(ViewerSchemeHandler(appRoot: root, vaultRoot: { [vault] in vault }), forURLScheme: "md")
        web = WKWebView(frame: CGRect(x: 0, y: 0, width: 900, height: 700), configuration: configuration)
        navigation = Navigation()
        web.navigationDelegate = navigation
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
    }

    private func waitUntil(_ timeout: TimeInterval = 20, _ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let end = Date().addingTimeInterval(timeout)
        while !condition() && Date() < end { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02)) }
        XCTAssertTrue(condition(), "Timed out", file: file, line: line)
    }

    private func js(_ script: String) -> Any? {
        var result: Any?
        var done = false
        web.evaluateJavaScript(script) { value, _ in result = value; done = true }
        waitUntil { done }
        return result
    }

    private func show(_ markdown: String, index: VaultResolving = FakeVault(notes: ["Plan.md"], files: ["img/pic.png"])) {
        let note = NoteRenderer.render(markdown: markdown, notePath: "n.md", resolver: index, loadNote: { _ in nil })
        let page = ViewerPage.html(note: note, title: "T", themeCSS: "body{background:#fff;color:#111}")
        let before = navigation.finished
        web.loadHTMLString(page, baseURL: URL(string: "md://vault/"))
        waitUntil { self.navigation.finished > before }
    }

    func testMathMermaidCodeAndImageAllWork() {
        show("""
        # Title

        Inline $a^2+b^2=c^2$ and display:

        $$\\int_0^1 x\\,dx$$

        ```mermaid
        graph TD; A-->B;
        ```

        ```python
        def f(): return 1
        ```

        ![[pic.png]]

        > [!tip] Handy
        > Callout text
        """)
        waitUntil { (self.js("document.querySelectorAll('.katex').length") as? Int) == 2 }
        waitUntil { (self.js("window.MacDownDiagrams ? MacDownDiagrams.pending : -1") as? Int) == 0 }
        XCTAssertEqual(js("document.querySelectorAll('.macdown-diagram-mermaid svg').length") as? Int, 1)
        waitUntil { (self.js("document.querySelectorAll('code.language-python .token').length") as? Int ?? 0) > 0 }
        waitUntil { (self.js("document.querySelector('img').naturalWidth") as? Int) == 1 }
        XCTAssertEqual(js("document.querySelectorAll('.callout[data-callout=tip]').length") as? Int, 1)
    }

    func testPlainNoteLoadsNoLibraries() {
        show("# Plain\n\nJust text.")
        XCTAssertEqual(js("typeof katex") as? String, "undefined")
        XCTAssertEqual(js("typeof mermaid") as? String, "undefined")
        XCTAssertEqual(js("typeof Prism") as? String, "undefined")
    }

    func testVaultHandlerServesFilesAndRefusesFoldersAndMissingOnes() {
        show("# x")
        // Loads a resource the way a page does (no CORS: pages cannot read these answers).
        func loads(_ tag: String, _ url: String) -> Bool? {
            var out: Bool?; var done = false
            let script = "return await new Promise(r => { const e = document.createElement('\(tag)'); e.onload = () => r(true); e.onerror = () => r(false); e.src = '\(url)'; document.head.appendChild(e); });"
            web.callAsyncJavaScript(script, arguments: [:], in: nil, in: .page) { result in
                if case let .success(v) = result { out = v as? Bool }; done = true
            }
            waitUntil { done }
            return out
        }
        XCTAssertEqual(loads("img", "md://vault/img/pic.png"), true)
        XCTAssertEqual(loads("img", "md://vault/img"), false, "Folders are not served")
        XCTAssertEqual(loads("img", "md://vault/missing.png"), false)
        XCTAssertEqual(loads("script", "md://app/KaTeX/katex-init.js"), true)
        XCTAssertEqual(loads("script", "md://app/KaTeX/missing.js"), false)
    }

    func testHeadingScrollHelper() {
        show("# One\n\n" + String(repeating: "filler paragraph\n\n", count: 80) + "## Target Heading\n\nend")
        XCTAssertEqual(js("window.scrollToHeading('target   heading!')") as? Bool, true)
        XCTAssertEqual(js("window.scrollToHeading('no such heading')") as? Bool, false)
    }
}
