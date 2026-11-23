import XCTest
import WebKit
@testable import MacDown

// MARK: - Pure helpers

final class PreviewHelpersTests: XCTestCase {
    func testURLConversionRoundTrip() {
        let file = URL(fileURLWithPath: "/Users/me/My Docs/a b.md")
        let preview = PreviewURL.previewURL(for: file)
        XCTAssertEqual(preview.scheme, "macdown-file")
        XCTAssertEqual(preview.path, "/Users/me/My Docs/a b.md")
        XCTAssertEqual(PreviewURL.fileURL(for: preview), file)
        let withFragment = URL(string: "macdown-file:///a/b.md#sec")!
        XCTAssertEqual(PreviewURL.fileURL(for: withFragment).absoluteString, "file:///a/b.md#sec")
        let web = URL(string: "https://example.com/x")!
        XCTAssertEqual(PreviewURL.fileURL(for: web), web)
    }

    func testRewriteChangesOnlyAttributes() {
        let html = """
        <link rel="stylesheet" href="file:///app/style.css"><img src='file:///a/b.png'>
        <script SRC = "file:///x.js"></script><pre><code>open file:///etc/hosts</code></pre>
        <a href="https://example.com">web</a><a href="notes.md">rel</a>
        """
        let out = PreviewURL.rewrite(html: html, localMathJax: nil)
        XCTAssertTrue(out.contains("href=\"macdown-file:///app/style.css\""))
        XCTAssertTrue(out.contains("src='macdown-file:///a/b.png'"))
        XCTAssertTrue(out.contains("SRC = \"macdown-file:///x.js\""))
        XCTAssertTrue(out.contains("open file:///etc/hosts"), "Text must not change")
        XCTAssertTrue(out.contains("href=\"https://example.com\""))
        XCTAssertTrue(out.contains("href=\"notes.md\""))
    }

    func testRewriteUsesTheBundledMathJax() {
        let cdn = "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.3/MathJax.js?config=TeX-AMS-MML_HTMLorMML"
        let local = URL(fileURLWithPath: "/App/MathJax/MathJax.js")
        let out = PreviewURL.rewrite(html: "<script src=\"\(cdn)\"></script>", localMathJax: local)
        XCTAssertEqual(out, "<script src=\"macdown-file:///App/MathJax/MathJax.js?config=TeX-AMS-MML_HTMLorMML\"></script>")
    }

    func testBaseURLOfAFolderGetsATrailingSlash() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("base-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertTrue(PreviewURL.baseURL(for: URL(fileURLWithPath: dir.path)).absoluteString.hasSuffix("/"))
        let file = dir.appendingPathComponent("doc.md")
        XCTAssertEqual(PreviewURL.baseURL(for: file).lastPathComponent, "doc.md", "A file stays a file")
    }

    func testRangeParsing() {
        XCTAssertEqual(PreviewSchemeHandler.parseRange("bytes=0-9", length: 100), 0..<10)
        XCTAssertEqual(PreviewSchemeHandler.parseRange("bytes=90-", length: 100), 90..<100)
        XCTAssertEqual(PreviewSchemeHandler.parseRange("bytes=-10", length: 100), 90..<100)
        XCTAssertEqual(PreviewSchemeHandler.parseRange("bytes=50-500", length: 100), 50..<100)
        XCTAssertNil(PreviewSchemeHandler.parseRange("bytes=100-110", length: 100))
        XCTAssertNil(PreviewSchemeHandler.parseRange("bytes=5-2", length: 100))
        XCTAssertNil(PreviewSchemeHandler.parseRange("bytes=0-1,5-6", length: 100))
        XCTAssertNil(PreviewSchemeHandler.parseRange("items=0-1", length: 100))
        XCTAssertNil(PreviewSchemeHandler.parseRange("bytes=0-1", length: 0))
    }

    func testMimeTypes() {
        XCTAssertEqual(PreviewSchemeHandler.mimeType(forPath: "/a/x.js"), "text/javascript")
        XCTAssertEqual(PreviewSchemeHandler.mimeType(forPath: "/a/x.CSS"), "text/css")
        XCTAssertEqual(PreviewSchemeHandler.mimeType(forPath: "/a/x.png"), "image/png")
        XCTAssertEqual(PreviewSchemeHandler.mimeType(forPath: "/a/x.svg"), "image/svg+xml")
        XCTAssertEqual(PreviewSchemeHandler.mimeType(forPath: "/a/x.woff2"), "font/woff2")
        XCTAssertEqual(PreviewSchemeHandler.mimeType(forPath: "/a/x.unknownext"), "application/octet-stream")
    }

    func testTextCount() {
        let count = TextCount(of: "Hello world\nsecond line")
        XCTAssertEqual(count.words, 4)
        XCTAssertEqual(count.characters, 22)
        XCTAssertEqual(count.charactersNoSpaces, 20)
        XCTAssertEqual(TextCount(of: ""), TextCount(of: ""))
        XCTAssertEqual(TextCount(of: "").words, 0)
        XCTAssertEqual(TextCount(of: "日本語のテキスト").characters, 8)
    }

    func testCSSColorParsing() throws {
        let c = try XCTUnwrap(CSSColor.parse("rgb(255, 128, 0)"))
        XCTAssertEqual(c.redComponent, 1, accuracy: 0.01)
        XCTAssertEqual(c.greenComponent, 128.0 / 255, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(CSSColor.parse("rgba(0, 0, 0, 0.5)")).alphaComponent, 0.5, accuracy: 0.01)
        XCTAssertNil(CSSColor.parse("rgba(0, 0, 0, 0)"), "Transparent is no color")
        XCTAssertNil(CSSColor.parse("transparent"))
        XCTAssertNil(CSSColor.parse("red"))
        XCTAssertNil(CSSColor.parse(""))
    }
}

// MARK: - Real web view

final class PreviewControllerTests: XCTestCase {
    private final class Recorder: NSObject, PreviewControllerDelegate {
        var finished = 0
        var mathJax = 0
        var scrolls = 0
        var links: [URL] = []
        var allowLinks = false
        func previewDidFinishLoading(_ preview: PreviewController) { finished += 1 }
        func previewMathJaxDidFinish(_ preview: PreviewController) { mathJax += 1 }
        func preview(_ preview: PreviewController, shouldNavigateTo url: URL) -> Bool { links.append(url); return allowLinks }
        func previewDidScroll(_ preview: PreviewController) { scrolls += 1 }
    }

    private var window: NSWindow!
    private var controller: PreviewController!
    private var recorder: Recorder!
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("macdown-preview-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        let container = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = container
        let placeholder = NSView(frame: container.bounds)
        placeholder.autoresizingMask = [.width, .height]
        container.addSubview(placeholder)
        recorder = Recorder()
        controller = PreviewController(replacing: placeholder, delegate: recorder)
    }

    override func tearDownWithError() throws {
        controller.tearDown()
        window.close()
        try? FileManager.default.removeItem(at: dir)
    }

    /// Spins the run loop until `condition` holds.
    private func waitUntil(_ timeout: TimeInterval = 8, _ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let end = Date().addingTimeInterval(timeout)
        while !condition() && Date() < end { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02)) }
        XCTAssertTrue(condition(), "Timed out", file: file, line: line)
    }

    private func load(_ html: String, base: URL? = nil) {
        let before = recorder.finished
        controller.loadHTML(html, baseURL: base ?? dir)
        waitUntil { recorder.finished > before }
    }

    private func js(_ script: String) -> Any? {
        var result: Any?
        var done = false
        controller.webView.evaluateJavaScript(script) { value, _ in result = value; done = true }
        waitUntil { done }
        return result
    }

    /// Runs async JavaScript (can `await`) and returns what it `return`s.
    private func asyncJS(_ body: String) -> Any? {
        var result: Any?
        var done = false
        controller.webView.callAsyncJavaScript(body, arguments: [:], in: nil, in: .page) { outcome in
            if case let .success(value) = outcome { result = value }
            done = true
        }
        waitUntil { done }
        return result
    }

    private func writePNG(_ name: String) throws {
        // A real 1 x 1 PNG made by AppKit.
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8,
                                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try data.write(to: dir.appendingPathComponent(name))
    }

    func testLocalImagesLoadThroughFileAndRelativePaths() throws {
        try writePNG("a.png"); try writePNG("b.png")
        load("<img id=a src=\"file://\(dir.path)/a.png\"><img id=b src=\"b.png\">")
        waitUntil { (self.js("document.getElementById('a').naturalWidth") as? Int) == 1 }
        waitUntil { (self.js("document.getElementById('b').naturalWidth") as? Int) == 1 }
    }

    func testLocalScriptsAndStylesLoad() throws {
        try "window.loadedFromDisk = 42;".write(to: dir.appendingPathComponent("s.js"), atomically: true, encoding: .utf8)
        try "body { margin-left: 33px; }".write(to: dir.appendingPathComponent("s.css"), atomically: true, encoding: .utf8)
        load("<link rel=stylesheet href=\"file://\(dir.path)/s.css\"><script src=\"file://\(dir.path)/s.js\"></script><body>x</body>")
        XCTAssertEqual(js("window.loadedFromDisk") as? Int, 42)
        XCTAssertEqual(js("getComputedStyle(document.body).marginLeft") as? String, "33px")
    }

    func testFilesWithSpacesAndUnicodeNames() throws {
        try writePNG("my image é.png")
        let encoded = "my%20image%20%C3%A9.png"
        load("<img id=a src=\"\(encoded)\">")
        waitUntil { (self.js("document.getElementById('a').naturalWidth") as? Int) == 1 }
    }

    func testMissingFilesAndFoldersAreErrorsNotCrashes() throws {
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("folder"), withIntermediateDirectories: true)
        load("<body>ok</body>")
        func status(_ path: String) -> Int? {
            asyncJS("const r = await fetch('macdown-file://\(path)'); return r.status;") as? Int
        }
        XCTAssertEqual(status(dir.appendingPathComponent("missing.png").path), 404)
        XCTAssertEqual(status(dir.appendingPathComponent("folder").path), 404, "Folders are not served")
    }

    func testRangeRequestsAreAnswered() throws {
        try "0123456789".write(to: dir.appendingPathComponent("r.txt"), atomically: true, encoding: .utf8)
        load("<body>ok</body>")
        let text = asyncJS("const r = await fetch('macdown-file://\(dir.path)/r.txt', {headers: {Range: 'bytes=2-4'}}); return r.status + ':' + r.headers.get('Content-Range');") as? String
        XCTAssertEqual(text, "206:bytes 2-4/10")
    }

    func testLinkClicksGoToTheDelegateAndAreBlockedWhenHandled() {
        load("<a id=a href=\"other.md\">x</a><a id=w href=\"https://example.com/p\">w</a>")
        recorder.allowLinks = false
        // A real click: send mouse events to the link's position.
        _ = js("document.getElementById('a').click(); 1")
        waitUntil { !recorder.links.isEmpty }
        XCTAssertEqual(recorder.links.first?.scheme, "file", "Local links reach the delegate as file URLs")
        XCTAssertEqual(recorder.links.first?.lastPathComponent, "other.md")
        let finishedBefore = recorder.finished
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        XCTAssertEqual(recorder.finished, finishedBefore, "A handled link must not load anything in the preview")
    }

    func testAnchorLinksStayOnThePageWhenAllowed() {
        load("<a id=a href=\"#end\">go</a><div style=\"height:3000px\"></div><h2 id=end>End</h2>")
        recorder.allowLinks = true
        _ = js("document.getElementById('a').click(); 1")
        waitUntil { (self.js("window.scrollY") as? Double ?? 0) > 100 }
    }

    func testMathJaxBridgeReachesTheDelegate() {
        load("<body>x</body>")
        _ = js("MathJaxListener.invokeCallbackForKey_('End'); 1")
        waitUntil { recorder.mathJax == 1 }
    }

    func testMetricsReportHeadingsAndHeight() {
        let filler = String(repeating: "<p>text text text</p>", count: 80)
        load("<h1>One</h1>\(filler)<h2>Two</h2>\(filler)<h3>Three</h3>\(filler)")
        waitUntil { controller.headerLocations.count == 3 }
        let tops = controller.headerLocations.map(\.doubleValue)
        XCTAssertEqual(tops, tops.sorted())
        XCTAssertLessThan(tops[0], tops[1])
        XCTAssertGreaterThan(controller.contentHeight, 1000)
        XCTAssertGreaterThan(controller.visibleHeight, 0)
    }

    func testScrollToAndScrollEvents() {
        load("<div style=\"height:5000px\">tall</div>")
        controller.scroll(toY: 700)
        waitUntil { abs(self.controller.scrollY - 700) < 1 }
        waitUntil { self.recorder.scrolls > 0 }
        controller.clearSelection()
    }

    func testTextCountAndBackgroundColor() {
        load("<body style=\"background:#102030\"><p>one two three</p><script>var hidden = 'not counted words';</script></body>")
        var counts: (Int, Int, Int)?
        controller.fetchTextCount { counts = ($0, $1, $2) }
        waitUntil { counts != nil }
        XCTAssertEqual(counts?.0, 3)

        var color: NSColor?
        var colorDone = false
        controller.fetchBackgroundColor { color = $0; colorDone = true }
        waitUntil { colorDone }
        XCTAssertEqual(color?.redComponent ?? 0, 16.0 / 255, accuracy: 0.01)
        XCTAssertEqual(color?.blueComponent ?? 0, 48.0 / 255, accuracy: 0.01)
    }

    func testReloadReplacesThePageAndTracksLoadingState() {
        XCTAssertFalse(controller.isLoading)
        controller.loadHTML("<body id=one>1</body>", baseURL: dir)
        XCTAssertTrue(controller.isLoading)
        waitUntil { !controller.isLoading }
        load("<body id=two>2</body>")
        XCTAssertEqual(js("document.body.id") as? String, "two")
    }

    func testPageZoom() {
        controller.setZoom(1.5)
        XCTAssertEqual(controller.webView.pageZoom, 1.5, accuracy: 0.001)
    }

    func testPrintOperationIsCreated() {
        load("<h1>Print me</h1>")
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        let operation = controller.printOperation(with: info)
        XCTAssertNotNil(operation.view)
        XCTAssertGreaterThan(operation.view!.frame.width, 100)
    }

    func testRealisticDocumentThroughTheWholePipeline() throws {
        // Markdown -> engine -> preview: heading ids, a local image, a table and a code block.
        try writePNG("pic.png")
        let o = MPMarkdownRenderOptions(); o.tables = true; o.fencedCode = true
        let body = CMarkEngine().renderMarkdown("# Title\n\n![pic](pic.png)\n\n|a|b|\n|-|-|\n|1|2|\n\n```swift\nlet x = 1\n```\n", options: o).html
        load("<html><body>\(body)</body></html>")
        XCTAssertEqual(js("document.querySelector('h1').id") as? String, "toc_0")
        waitUntil { (self.js("document.querySelector('img').naturalWidth") as? Int) == 1 }
        XCTAssertEqual(js("document.querySelectorAll('td').length") as? Int, 2)
        XCTAssertEqual(js("document.querySelector('pre code').className") as? String, "language-swift")
    }
}
