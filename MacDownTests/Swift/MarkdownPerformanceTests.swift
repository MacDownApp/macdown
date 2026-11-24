import XCTest
@testable import MacDown

/// Benchmarks for the budgets in docs/MODERNIZATION_PLAN.md (section 2). Each test
/// records timings with `measure` and asserts a generous hard limit, so a large
/// regression fails the build while normal noise does not. Baselines are in
/// docs/benchmarks.md.
final class MarkdownPerformanceTests: XCTestCase {
    let engine = CMarkEngine()

    private func options(allExtensions: Bool) -> MPMarkdownRenderOptions {
        let o = MPMarkdownRenderOptions()
        o.tables = true; o.fencedCode = true; o.footnotes = true; o.autolink = true
        o.strikethrough = true; o.intraEmphasis = true
        if allExtensions {
            o.underline = true; o.highlight = true; o.quote = true; o.superscript = true
            o.math = true; o.mathInlineDollar = true; o.taskList = true; o.rendersTOC = true
            o.smartyPants = true
        }
        return o
    }

    /// A realistic document of about `bytes` bytes.
    private func document(_ bytes: Int) -> String {
        let block = """
        ## Section heading

        A paragraph with *emphasis*, **strong text**, `inline code`, ==marked== text, x^2, and a [link](http://example.com/path?query=1) to somewhere else. It runs long enough to wrap over several lines in a typical editor window, with math like $a_1 + b_2$ in it.

        - first item
        - [ ] second item with `code`
            - nested item

        | Name | Value |
        |------|-------|
        | a | 1 |
        | b | 2 |

        ```python
        def f(x):
            return x * 2
        ```


        """
        return String(repeating: block, count: bytes / block.utf8.count + 1)
    }

    private func run(bytes: Int, limit: TimeInterval, allExtensions: Bool) {
        let doc = document(bytes)
        let o = options(allExtensions: allExtensions)
        _ = engine.renderMarkdown(doc, options: o)   // Warm up (loads Prism tables).

        measure { _ = engine.renderMarkdown(doc, options: o) }

        var best = TimeInterval.greatestFiniteMagnitude
        for _ in 0..<3 {
            let start = Date()
            _ = engine.renderMarkdown(doc, options: o)
            best = min(best, Date().timeIntervalSince(start))
        }
        XCTAssertLessThan(best, limit,
                          "\(bytes) bytes took \(Int(best * 1000)) ms (limit \(Int(limit * 1000)) ms)")
    }

    // Plan budget: preview update < 500 ms for a 1 MB document.
    func testRender10KB() { run(bytes: 10 * 1024, limit: 0.05, allExtensions: false) }
    func testRender100KB() { run(bytes: 100 * 1024, limit: 0.15, allExtensions: false) }
    func testRender1MB() { run(bytes: 1024 * 1024, limit: 0.5, allExtensions: false) }
    func testRender5MB() { run(bytes: 5 * 1024 * 1024, limit: 2.5, allExtensions: false) }

    func testRender1MBWithAllExtensions() { run(bytes: 1024 * 1024, limit: 0.5, allExtensions: true) }
}
