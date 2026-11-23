import XCTest
@testable import MacDown

/// Loads a real document window from the nib and checks the new preview end to end.
final class DocumentPreviewIntegrationTests: XCTestCase {
    private func waitUntil(_ timeout: TimeInterval = 10, _ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let end = Date().addingTimeInterval(timeout)
        while !condition() && Date() < end { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02)) }
        XCTAssertTrue(condition(), "Timed out", file: file, line: line)
    }

    private func evaluate(_ preview: PreviewController, _ script: String) -> Any? {
        var result: Any?
        var done = false
        preview.webView.evaluateJavaScript(script) { value, _ in result = value; done = true }
        waitUntil { done }
        return result
    }

    func testDocumentWindowLoadsRendersAndCleansUp() throws {
        let document = MPDocument()
        document.makeWindowControllers()
        _ = document.windowControllers.first?.window     // The nib (MPDocument.xib) loads on first access.
        defer { document.close() }

        let preview = try XCTUnwrap(document.value(forKey: "previewController") as? PreviewController,
                                    "The preview controller was not created from the nib")
        XCTAssertTrue(preview.webView.superview is NSSplitView, "The web view must sit in the split view")
        if let placeholder = document.value(forKey: "previewPlaceholder") as? NSView {
            XCTAssertNil(placeholder.superview, "The placeholder must be out of the view hierarchy")
        }

        document.markdown = "# Hello Preview\n\nSome *text* with `code`.\n\n```swift\nlet x = 1\n```\n"
        let renderer = try XCTUnwrap(document.value(forKey: "renderer") as? MPRenderer)
        renderer.parseAndRenderNow()

        waitUntil { (self.evaluate(preview, "document.querySelector('h1') ? document.querySelector('h1').textContent : ''") as? String) == "Hello Preview" }
        XCTAssertEqual(evaluate(preview, "document.querySelector('pre code').className") as? String, "language-swift")
        XCTAssertEqual(evaluate(preview, "document.querySelector('em').textContent") as? String, "text")

        // The preview shows the new text after an edit.
        document.markdown = "# Changed\n"
        renderer.parseAndRenderNow()
        waitUntil { (self.evaluate(preview, "document.querySelector('h1') ? document.querySelector('h1').textContent : ''") as? String) == "Changed" }
    }

    func testBundledStyleAndScriptsLoadThroughTheScheme() throws {
        let document = MPDocument()
        document.makeWindowControllers()
        _ = document.windowControllers.first?.window
        defer { document.close() }
        let preview = try XCTUnwrap(document.value(forKey: "previewController") as? PreviewController)
        document.markdown = "# Styled\n\n- [ ] task\n"
        (document.value(forKey: "renderer") as? MPRenderer)?.parseAndRenderNow()
        waitUntil { (self.evaluate(preview, "!!document.querySelector('h1')") as? Bool) == true }
        // The base style (from the app bundle, via macdown-file://) must have been applied.
        waitUntil { (self.evaluate(preview, "getComputedStyle(document.querySelector('h1')).fontWeight") as? String).map { $0 != "400" } ?? false }
        let sheets = evaluate(preview, "document.styleSheets.length") as? Int ?? 0
        XCTAssertGreaterThan(sheets, 0)
    }
}
