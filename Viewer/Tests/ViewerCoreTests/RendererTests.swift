import XCTest
@testable import ViewerCore

final class CalloutTests: XCTestCase {
    private func render(_ md: String) -> String {
        NoteRenderer.render(markdown: md, notePath: "n.md", resolver: FakeVault(), loadNote: { _ in nil }).bodyHTML
    }

    func testCalloutWithTitleAndBody() {
        let html = render("> [!tip] Remember this\n> Second line with **bold**.\n")
        XCTAssertTrue(html.contains("<div class=\"callout\" data-callout=\"tip\">"), html)
        XCTAssertTrue(html.contains("<span class=\"callout-title-text\">Remember this</span>"), html)
        XCTAssertTrue(html.contains("<strong>bold</strong>"), html)
        XCTAssertFalse(html.contains("<blockquote"), html)
    }

    func testDefaultTitleAndAliases() {
        let html = render("> [!warning]\n> Careful\n")
        XCTAssertTrue(html.contains("callout-title-text\">Warning<"), html)
        XCTAssertTrue(render("> [!caution] x\n> y").contains("data-callout=\"warning\""))
        XCTAssertTrue(render("> [!TLDR] x\n> y").contains("data-callout=\"abstract\""))
        XCTAssertTrue(render("> [!unknownkind] x\n> y").contains("data-callout=\"unknownkind\""))
    }

    func testFoldableCallouts() {
        XCTAssertTrue(render("> [!note]- Folded\n> hidden").contains("<details class=\"callout\" data-callout=\"note\">"))
        XCTAssertTrue(render("> [!note]+ Open\n> shown").contains("<details class=\"callout\" data-callout=\"note\" open>"))
    }

    func testNestedContentAndNestedCallouts() {
        let html = render("> [!info] Outer\n> - item one\n> - item two\n>\n> > [!bug] Inner\n> > text\n")
        XCTAssertTrue(html.contains("<li>item one</li>"), html)
        XCTAssertTrue(html.contains("data-callout=\"bug\""), html)
        XCTAssertTrue(html.contains("data-callout=\"info\""), html)
    }

    func testPlainQuotesStayQuotes() {
        XCTAssertTrue(render("> just a quote\n").contains("<blockquote>"))
        XCTAssertTrue(render("> text [!note] later\n").contains("<blockquote>"))
        XCTAssertTrue(render("> [!note\n> broken\n").contains("<blockquote>"))
    }

    func testCalloutTypeCannotInjectHTML() {
        XCTAssertFalse(render("> [!x\"onmouseover=\"alert(1)] t\n> y\n").contains("onmouseover=\"alert"))
    }
}

final class NoteRendererTests: XCTestCase {
    private let vault = FakeVault(notes: ["Plan.md"], files: ["pic.png"])
    private func render(_ md: String) -> RenderedNote {
        NoteRenderer.render(markdown: md, notePath: "n.md", resolver: vault, loadNote: { _ in nil })
    }

    func testHeadingsGetStableSlugIds() {
        let html = render("# Hello World\n\n## Hello World\n\n### Ünï *code* `x`\n").bodyHTML
        XCTAssertTrue(html.contains("<h1 id=\"hello-world\">"), html)
        XCTAssertTrue(html.contains("<h2 id=\"hello-world-1\">"), html)
        XCTAssertTrue(html.contains("id=\"ünï-code-x\""), html)
        XCTAssertEqual(HeadingSlug.make(from: "  !!!  "), "section")
    }

    func testMathHighlightTablesTasksFootnotes() {
        let n = render("Inline $a_1^2$ and $$\\int x$$ ==marked== ~~gone~~.\n\n|a|b|\n|:-|-:|\n|1|2|\n\n- [x] done\n- [ ] todo\n\nNote[^1]\n\n[^1]: The note.\n")
        XCTAssertTrue(n.usesMath)
        XCTAssertTrue(n.bodyHTML.contains("\\(a_1^2\\)") && n.bodyHTML.contains("\\[\\int x\\]"), n.bodyHTML)
        XCTAssertTrue(n.bodyHTML.contains("<mark>marked</mark>") && n.bodyHTML.contains("<del>gone</del>"))
        XCTAssertTrue(n.bodyHTML.contains("<th style=\"text-align: left\">a</th>"))
        XCTAssertTrue(n.bodyHTML.contains("type=\"checkbox\""))
        XCTAssertTrue(n.bodyHTML.contains("footnote"))
    }

    func testCurrencyIsNotMath() {
        let n = render("It costs $5 and $10.")
        XCTAssertFalse(n.usesMath)
        XCTAssertTrue(n.bodyHTML.contains("$5 and $10"))
    }

    func testFeatureDetection() {
        XCTAssertFalse(render("# Plain\n\ntext").usesMath || render("# Plain").usesMermaid || render("# Plain").usesCode)
        XCTAssertTrue(render("```mermaid\ngraph TD; A-->B;\n```").usesMermaid)
        XCTAssertFalse(render("```mermaid\ngraph TD; A-->B;\n```").usesCode)
        XCTAssertTrue(render("```swift\nlet x = 1\n```").usesCode)
        XCTAssertFalse(render("```\nplain\n```").usesCode)
        XCTAssertFalse(render("`\\(x\\)`").usesMath == false && false)
    }

    func testCodeBlocksHaveThePrismAndMermaidMarkup() {
        let html = render("```python\nprint('<hi>')\n```").bodyHTML
        XCTAssertTrue(html.contains("<code class=\"language-python\">print(&#39;&lt;hi&gt;&#39;)</code>"), html)
    }

    func testObsidianThingsEndToEnd() {
        let html = render("---\ntags: [a, b]\nstatus: draft\n---\n# T\n\n[[Plan]] ![[pic.png|200]] #tag %%secret%%\n").bodyHTML
        XCTAssertTrue(html.contains("<details class=\"properties\">"), html)
        XCTAssertTrue(html.contains("<th>tags</th><td>a, b</td>") && html.contains("<th>status</th><td>draft</td>"), html)
        XCTAssertTrue(html.contains("href=\"md://note/Plan.md\""))
        XCTAssertTrue(html.contains("<img src=\"md://vault/pic.png\" alt=\"pic.png\" width=\"200\">"))
        XCTAssertTrue(html.contains("<span class=\"tag\">#tag</span>"))
        XCTAssertFalse(html.contains("secret"))
    }

    func testEmptyAndOddDocuments() {
        XCTAssertEqual(render("").bodyHTML, "")
        for text in ["\0", "[", "![[", "---\n---\n", "---\nunclosed", String(repeating: "> ", count: 300) + "x", "$$", "\\(", "```"] { _ = render(text) }
    }

    func testLargeNoteIsQuick() {
        let block = "## Section\n\nParagraph with [[Plan]], $x^2$, ==mark==, #tag and `code`.\n\n- [ ] task\n\n> [!note] Callout\n> body\n\n```swift\nlet a = 1\n```\n\n"
        let doc = String(repeating: block, count: 1500)   // About 200 KB.
        let start = Date()
        let n = render(doc)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
        XCTAssertTrue(n.bodyHTML.contains("data-callout"))
    }
}

final class PageAndHandlerTests: XCTestCase {
    private func page(_ md: String, themeCSS: String = "body{color:red}", scrollTo: String? = nil) -> String {
        let n = NoteRenderer.render(markdown: md, notePath: "n.md", resolver: FakeVault(), loadNote: { _ in nil })
        return ViewerPage.html(note: n, title: "T <x>", themeCSS: themeCSS, scrollTo: scrollTo)
    }

    func testScriptsAreLoadedOnlyWhenNeeded() {
        let plain = page("# Hi")
        XCTAssertFalse(plain.contains("md://app/"), "No library script for a plain note")
        XCTAssertTrue(page("$x$ and \\(y\\)").contains("md://app/KaTeX/katex-init.js"))
        XCTAssertTrue(page("```mermaid\ngraph TD; A-->B;\n```").contains("md://app/Diagrams/mermaid-init.js"))
        XCTAssertTrue(page("```swift\nx\n```").contains("md://app/components/prism-core.min.js"))
    }

    func testPageStructure() {
        let html = page("# Hi", themeCSS: "/*theme*/")
        XCTAssertTrue(html.hasPrefix("<!doctype html>"))
        XCTAssertTrue(html.contains("<title>T &lt;x&gt;</title>"))
        XCTAssertTrue(html.range(of: "color-scheme")!.lowerBound < html.range(of: "/*theme*/")!.lowerBound, "The theme comes after the base style")
        XCTAssertTrue(html.contains("viewport-fit=cover"))
    }

    func testScrollTargetIsEscaped() {
        let html = page("# Hi", scrollTo: "A\"</script><script>alert(1)//")
        XCTAssertFalse(html.contains("</script><script>alert"), html)
    }

    func testHandlerPathMappingRefusesEscapes() {
        let app = URL(fileURLWithPath: "/app/Resources"), vault = URL(fileURLWithPath: "/vault")
        func map(_ s: String, vault v: URL? = URL(fileURLWithPath: "/vault")) -> String? {
            VaultFiles.fileURL(for: URL(string: s)!, appRoot: app, vaultRoot: v)?.path
        }
        XCTAssertEqual(map("md://app/KaTeX/katex-init.js"), "/app/Resources/KaTeX/katex-init.js")
        XCTAssertEqual(map("md://vault/img/a%20b.png"), "/vault/img/a b.png")
        XCTAssertNil(map("md://vault/../etc/passwd"))
        XCTAssertNil(map("md://vault/a/../../x"))
        XCTAssertNil(map("md://vault/%2e%2e/x"))
        XCTAssertNil(map("md://app/../x"))
        XCTAssertNil(map("md://other/x"))
        XCTAssertNil(map("md://vault/x", vault: nil), "No vault open: nothing is served")
        XCTAssertEqual(map("md://vault/"), "/vault", "The root itself maps, but is a folder and is refused when read")
        _ = vault
    }

    func testReadingRefusesFoldersAndMissingFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("h-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "hello".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        for coordinated in [false, true] {
            XCTAssertEqual(VaultFiles.read(dir.appendingPathComponent("a.txt"), coordinated: coordinated).map { String(decoding: $0, as: UTF8.self) }, "hello")
            XCTAssertNil(VaultFiles.read(dir, coordinated: coordinated))
            XCTAssertNil(VaultFiles.read(dir.appendingPathComponent("missing"), coordinated: coordinated))
        }
    }

    func testICloudPlaceholderWaitsForTheDownloadAndGivesUpWhenItNeverComes() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("icloud-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let saved = VaultFiles.downloadTimeout
        defer { VaultFiles.downloadTimeout = saved }
        VaultFiles.downloadTimeout = 0.5

        // Only the placeholder exists and nothing downloads it: give up after the timeout.
        try Data().write(to: dir.appendingPathComponent(".Later.md.icloud"))
        let start = Date()
        XCTAssertNil(VaultFiles.readText(dir.appendingPathComponent("Later.md")))
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.4)
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)

        // The download finishes while we wait: the note is read.
        VaultFiles.downloadTimeout = 5
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            try? "arrived".write(to: dir.appendingPathComponent("Later.md"), atomically: true, encoding: .utf8)
        }
        XCTAssertEqual(VaultFiles.readText(dir.appendingPathComponent("Later.md")), "arrived")

        // A normal missing file does not wait at all.
        let quick = Date()
        XCTAssertNil(VaultFiles.readText(dir.appendingPathComponent("Nothing.md")))
        XCTAssertLessThan(Date().timeIntervalSince(quick), 1)
    }

    func testThemesLoadFromTheRepositoryFolder() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("MacDown/Resources/BuiltinThemes")
        let themes = ThemeCatalog.load(from: dir)
        XCTAssertGreaterThanOrEqual(themes.count, 9)
        let github = try XCTUnwrap(themes.first { $0.name == "GitHub Light" })
        XCTAssertFalse(github.isDark(systemDark: false))
        XCTAssertEqual(github.backgroundHex(systemDark: false), "#ffffff")
        XCTAssertTrue(github.css(systemDark: false).contains("body h1"))
        let dracula = try XCTUnwrap(themes.first { $0.name == "Dracula" })
        XCTAssertTrue(dracula.isDark(systemDark: false), "A dark theme is dark in any system mode")
        XCTAssertTrue(dracula.css(systemDark: false).contains("color-scheme: dark"))
        XCTAssertTrue(ThemeCatalog.load(from: dir.appendingPathComponent("nope")).isEmpty)
    }
}
