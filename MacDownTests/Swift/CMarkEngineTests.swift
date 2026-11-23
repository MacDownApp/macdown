import XCTest
@testable import MacDown

/// Behavior tests for the cmark based engine, plus golden-file tests over the
/// corpus in Snapshots/corpus. Goldens are in Snapshots/golden.
///
/// To (re)record goldens, run the tests with
///     TEST_RUNNER_MACDOWN_RECORD_SNAPSHOTS=<absolute path to Snapshots/golden>
/// and review the diff before committing.
final class CMarkEngineTests: XCTestCase {
    let engine = CMarkEngine()

    private func defaults() -> MPMarkdownRenderOptions {
        let o = MPMarkdownRenderOptions()
        o.tables = true; o.fencedCode = true; o.footnotes = true; o.intraEmphasis = true
        return o
    }

    private func extended() -> MPMarkdownRenderOptions {
        let o = defaults()
        o.autolink = true; o.strikethrough = true; o.underline = true; o.highlight = true
        o.quote = true; o.superscript = true; o.math = true; o.mathInlineDollar = true
        o.intraEmphasis = false; o.taskList = true; o.hardWrap = true; o.lineNumbers = true
        o.smartyPants = true; o.rendersTOC = true; o.detectsFrontMatter = true
        return o
    }

    private func html(_ markdown: String, _ options: MPMarkdownRenderOptions? = nil) -> String {
        engine.renderMarkdown(markdown, options: options ?? defaults()).html
    }

    // MARK: Basics

    func testParagraphAndInline() {
        XCTAssertEqual(html("Hello *world* and **you**.\n"), "<p>Hello <em>world</em> and <strong>you</strong>.</p>\n")
        XCTAssertEqual(html(""), "")
    }

    func testRawHTMLPassesThrough() {
        XCTAssertTrue(html("<div class=\"x\">raw</div>\n").contains("<div class=\"x\">raw</div>"))
    }

    // MARK: Headings and TOC

    func testHeadingsGetSequentialIds() {
        let out = html("# One\n\n## Two `c`\n\nSetext\n======\n")
        XCTAssertTrue(out.contains("<h1 id=\"toc_0\">One</h1>"), out)
        XCTAssertTrue(out.contains("<h2 id=\"toc_1\">Two <code>c</code></h2>"), out)
        XCTAssertTrue(out.contains("<h1 id=\"toc_2\">Setext</h1>"), out)
    }

    func testTableOfContentsReplacesMarker() {
        let o = defaults(); o.rendersTOC = true
        let out = html("[TOC]\n\n# A\n## B\n# C\n", o)
        XCTAssertTrue(out.hasPrefix("<ul class=\"toc\">\n<li>\n<a href=\"#toc_0\">A</a>"), out)
        XCTAssertTrue(out.contains("<a href=\"#toc_1\">B</a>"))
        XCTAssertTrue(out.contains("<a href=\"#toc_2\">C</a>"))
        XCTAssertFalse(out.contains("[TOC]"))
    }

    func testTableOfContentsMarkerIsKeptWhenDisabled() {
        XCTAssertTrue(html("[TOC]\n\n# A\n").contains("[TOC]"))
    }

    func testTableOfContentsBuilder() {
        let entries = [
            TableOfContents.Entry(level: 2, html: "A", index: 0),
            TableOfContents.Entry(level: 3, html: "B", index: 1),
            TableOfContents.Entry(level: 2, html: "C", index: 2),
        ]
        XCTAssertEqual(TableOfContents.html(for: entries),
            "<ul class=\"toc\">\n<li>\n<a href=\"#toc_0\">A</a>\n<ul>\n<li>\n<a href=\"#toc_1\">B</a>\n</li>\n</ul>\n</li>\n<li>\n<a href=\"#toc_2\">C</a>\n</li>\n</ul>\n")
        XCTAssertEqual(TableOfContents.html(for: []), "")
    }

    // MARK: Code blocks

    func testFencedCodeBlockMarkup() {
        let out = html("```python\ndef f():\n    return \"x\" < 1\n```\n")
        XCTAssertEqual(out, "<div><pre><code class=\"language-python\">def f():\n    return &quot;x&quot; &lt; 1</code></pre></div>\n")
    }

    func testCodeWithoutLanguageIsNone() {
        XCTAssertTrue(html("```\nplain\n```\n").contains("class=\"language-none\">plain</code>"))
        XCTAssertTrue(html("    indented\n").contains("class=\"language-none\">indented</code>"))
    }

    func testLanguageAliasesAndDependenciesAreReported() {
        let result = engine.renderMarkdown("```js\nvar x;\n```\n\n```cpp\nint y;\n```\n", options: defaults())
        XCTAssertTrue(result.html.contains("language-javascript"))
        XCTAssertTrue(result.languages.contains("javascript"), "\(result.languages)")
        XCTAssertTrue(result.languages.contains("cpp"))
        XCTAssertTrue(result.languages.contains("c"), "C++ needs C: \(result.languages)")
        XCTAssertLessThan(result.languages.firstIndex(of: "c")!, result.languages.firstIndex(of: "cpp")!,
                          "Dependencies must load first")
    }

    func testLineNumbersAndInformation() {
        let o = defaults(); o.lineNumbers = true; o.codeBlockInformation = true
        let out = html("```ruby:file.rb\nputs 1\n```\n", o)
        XCTAssertEqual(out, "<div><pre class=\"line-numbers\" data-information=\"file.rb\"><code class=\"language-ruby\">puts 1</code></pre></div>\n")
    }

    func testCodeInsideListsAndQuotesIsRewritten() {
        let out = html("- item\n\n  ```c\n  int x;\n  ```\n\n> ```\n> q\n> ```\n")
        XCTAssertEqual(out.components(separatedBy: "<div><pre>").count - 1, 2, out)
    }

    // MARK: Alerts

    func testAlertBox() {
        let out = html("> [!NOTE]\n> Remember this.\n")
        XCTAssertEqual(out, "<div class=\"markdown-alert markdown-alert-note\">\n<p class=\"markdown-alert-title\">Note</p>\n<p>Remember this.</p>\n</div>\n")
    }

    func testAlertBoxVariants() {
        for (marker, kind, title) in [("TIP", "tip", "Tip"), ("IMPORTANT", "important", "Important"),
                                      ("WARNING", "warning", "Warning"), ("CAUTION", "caution", "Caution")] {
            let out = html("> [!\(marker)]\n> text\n")
            XCTAssertTrue(out.contains("markdown-alert-\(kind)\">"), out)
            XCTAssertTrue(out.contains(">\(title)</p>"), out)
        }
    }

    func testAlertBoxKeepsRichContent() {
        let out = html("> [!WARNING]\n> First *line*\n>\n> - item\n>\n> ```c\n> int x;\n> ```\n")
        XCTAssertTrue(out.contains("<p>First <em>line</em></p>"), out)
        XCTAssertTrue(out.contains("<li>item</li>"), out)
        XCTAssertTrue(out.contains("language-c"), out)
        XCTAssertFalse(out.contains("<blockquote"), out)
    }

    func testAlertMarkerAloneOnItsLine() {
        let out = html("> [!TIP]\n>\n> Body text\n")
        XCTAssertTrue(out.contains("<p class=\"markdown-alert-title\">Tip</p>\n<p>Body text</p>"), out)
    }

    func testPlainBlockQuotesAndUnknownMarkersStayQuotes() {
        XCTAssertTrue(html("> just a quote\n").contains("<blockquote>"))
        XCTAssertTrue(html("> [!UNKNOWN]\n> x\n").contains("<blockquote>"))
        XCTAssertTrue(html("> text [!NOTE] later\n").contains("<blockquote>"))
    }

    // MARK: GFM features

    func testTableAlignment() {
        let out = html("|a|b|c|\n|:-|:-:|-:|\n|1|2|3|\n")
        XCTAssertTrue(out.contains("<th style=\"text-align: left\">a</th>"), out)
        XCTAssertTrue(out.contains("<th style=\"text-align: center\">b</th>"), out)
        XCTAssertTrue(out.contains("<th style=\"text-align: right\">c</th>"), out)
    }

    func testTablesCanBeDisabled() {
        let o = defaults(); o.tables = false
        XCTAssertFalse(html("|a|b|\n|-|-|\n|1|2|\n", o).contains("<table"))
    }

    func testStrikethroughNeedsOption() {
        XCTAssertFalse(html("~~x~~").contains("<del>"))
        let o = defaults(); o.strikethrough = true
        XCTAssertTrue(html("~~x~~", o).contains("<del>x</del>"))
        XCTAssertFalse(html("~x~", o).contains("<del>"))
    }

    func testAutolinkNeedsOption() {
        XCTAssertFalse(html("see www.example.com").contains("<a "))
        let o = defaults(); o.autolink = true
        XCTAssertTrue(html("see www.example.com", o).contains("<a href=\"http://www.example.com\">"))
    }

    func testTaskListMarkup() {
        let o = defaults(); o.taskList = true
        let out = html("- [ ] todo\n- [x] done\n- plain\n", o)
        XCTAssertTrue(out.contains("<li class=\"task-list-item\"><input type=\"checkbox\"> todo</li>"), out)
        XCTAssertTrue(out.contains("<li class=\"task-list-item\"><input type=\"checkbox\" checked> done</li>"), out)
        XCTAssertTrue(out.contains("<li>plain</li>"), out)
    }

    func testLooseTaskListKeepsParagraph() {
        let o = defaults(); o.taskList = true
        let out = html("- [ ] one\n\n- [x] two\n", o)
        XCTAssertTrue(out.contains("<li class=\"task-list-item\"><p><input type=\"checkbox\"> one</p>"), out)
    }

    func testTaskListNeedsOption() {
        XCTAssertFalse(html("- [ ] todo\n").contains("checkbox"))
    }

    func testFootnotes() {
        let out = html("Text[^1].\n\n[^1]: The note.\n")
        XCTAssertTrue(out.contains("footnote"), out)
        XCTAssertTrue(out.contains("The note."), out)
        let o = defaults(); o.footnotes = false
        XCTAssertFalse(html("Text[^1].\n\n[^1]: The note.\n", o).contains("footnotes"))
    }

    func testFootnotesWorkWithSuperscriptEnabled() {
        let out = html("Text[^a] and x^2.\n\n[^a]: The note.\n", extended())
        XCTAssertTrue(out.contains("footnote-ref"), out)
        XCTAssertTrue(out.contains("x<sup>2</sup>"), out)
        XCTAssertFalse(out.contains("[<sup>"), out)
    }

    func testEscapedFootnoteSyntaxShowsAsText() {
        let out = html("Write [\\^4] for a note.\n\n[^4]: def\n", extended())
        XCTAssertTrue(out.contains("[^4] for a note."), out)
        XCTAssertFalse(out.contains("]]"), out)
    }

    func testIntraWordEmphasisOption() {
        let off = defaults(); off.intraEmphasis = false
        XCTAssertTrue(html("2*3*4", off).contains("2*3*4"))
        XCTAssertTrue(html("2*3*4", defaults()).contains("2<em>3</em>4"))
    }

    func testHardWrapAndSmartyPants() {
        let o = defaults(); o.hardWrap = true
        XCTAssertTrue(html("a\nb\n", o).contains("a<br />\nb"))
        let s = defaults(); s.smartyPants = true
        XCTAssertTrue(html("\"quoted\" -- dash...", s).contains("“quoted” – dash…"))
    }

    // MARK: MacDown extensions

    func testExtensionSyntaxEndToEnd() {
        let o = extended()
        let out = html("==hi== x^2 _u_ $a_b$ and \"q\"\n", o)
        XCTAssertTrue(out.contains("<mark>hi</mark>"), out)
        XCTAssertTrue(out.contains("x<sup>2</sup>"), out)
        XCTAssertTrue(out.contains("<u>u</u>"), out)
        XCTAssertTrue(out.contains("\\(a_b\\)"), out)
    }

    func testExtensionSyntaxStaysOutOfCode() {
        let out = html("`==x==`\n\n```\n$a$ ^b\n```\n", extended())
        XCTAssertTrue(out.contains("<code>==x==</code>"), out)
        XCTAssertTrue(out.contains("$a$ ^b"), out)
    }

    func testCurrencyIsNotMathAnymore() {
        // The old Hoedown engine turned this into broken math.
        XCTAssertTrue(html("Price is $5 and $10 total.", extended()).contains("Price is $5 and $10 total."))
    }

    // MARK: Front matter

    func testFrontMatterBecomesTable() {
        let o = defaults(); o.detectsFrontMatter = true
        let out = html("---\ntitle: T\n---\n\n# Body\n", o)
        XCTAssertTrue(out.hasPrefix("<table"), out)
        XCTAssertTrue(out.contains("<h1 id=\"toc_0\">Body</h1>"), out)
    }

    func testFrontMatterIgnoredWhenDisabled() {
        XCTAssertFalse(html("---\ntitle: T\n---\n\nbody\n").hasPrefix("<table"))
    }

    // MARK: Statelessness and robustness

    func testNoHiddenStateBetweenRenders() {
        let a = "# A\n\n```python\nx\n```\n"
        let first = html(a)
        _ = html("plain")
        XCTAssertEqual(html(a), first)
    }

    func testConcurrentRenders() {
        let doc = String(repeating: "# H\n\n```swift\nlet x = 1\n```\n\n- [ ] a ==b==\n\n", count: 200)
        let o = extended()
        let expected = html(doc, o)
        DispatchQueue.concurrentPerform(iterations: 16) { _ in
            XCTAssertEqual(engine.renderMarkdown(doc, options: o).html, expected)
        }
    }

    func testInvalidAndOddInputDoesNotCrash() {
        let inputs = ["\0", "\u{FFFD}", "[", "![", "```", "<", "&", String(repeating: ">", count: 5000),
                      String(repeating: "- ", count: 2000), "[TOC]", "---\n---\n"]
        for input in inputs { _ = html(input, extended()) }
    }

    // MARK: Golden files

    private var corpus: URL { Bundle(for: CMarkEngineTests.self).resourceURL!.appendingPathComponent("Snapshots/corpus") }
    private var golden: URL { Bundle(for: CMarkEngineTests.self).resourceURL!.appendingPathComponent("Snapshots/golden") }

    private func checkCorpus(variant: String, options: MPMarkdownRenderOptions) throws {
        let record = ProcessInfo.processInfo.environment["MACDOWN_RECORD_SNAPSHOTS"]
        let names = try FileManager.default.contentsOfDirectory(atPath: corpus.path)
            .filter { $0.hasSuffix(".md") }.sorted()
        XCTAssertGreaterThan(names.count, 10)
        for file in names {
            let name = (file as NSString).deletingPathExtension
            let markdown = try String(contentsOf: corpus.appendingPathComponent(file), encoding: .utf8)
            let output = engine.renderMarkdown(markdown, options: options).html
            let goldenName = "\(name).\(variant).html"
            if let record = record {
                let dir = URL(fileURLWithPath: record)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try output.write(to: dir.appendingPathComponent(goldenName), atomically: true, encoding: .utf8)
                continue
            }
            let expected = try? String(contentsOf: golden.appendingPathComponent(goldenName), encoding: .utf8)
            XCTAssertNotNil(expected, "No golden file for \(goldenName)")
            XCTAssertEqual(output, expected, "Output changed for \(name) (\(variant))")
        }
    }

    func testCorpusWithDefaultOptions() throws { try checkCorpus(variant: "default", options: defaults()) }
    func testCorpusWithAllExtensions() throws { try checkCorpus(variant: "extended", options: extended()) }
}
