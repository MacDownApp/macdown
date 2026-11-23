import XCTest
@testable import MacDown

final class LinterTests: XCTestCase {
    private func lint(_ text: String, rules: [String]? = nil, options: LintOptions = LintOptions()) -> [LintDiagnostic] {
        Linter(enabledRules: Set(rules ?? LintRules.all), options: options).lint(text)
    }

    private func names(_ diagnostics: [LintDiagnostic]) -> [String] { diagnostics.map(\.rule) }

    // MARK: Rule selection

    func testDefaultRulesExcludeLineLength() {
        XCTAssertEqual(LintRules.resolve([]), Set(LintRules.defaults))
        XCTAssertFalse(LintRules.resolve([]).contains("line-length"))
    }

    func testRuleSelection() {
        XCTAssertEqual(LintRules.resolve(["no-bare-urls"]), ["no-bare-urls"])
        XCTAssertEqual(LintRules.resolve(["-no-bare-urls"]), Set(LintRules.defaults).subtracting(["no-bare-urls"]))
        XCTAssertEqual(LintRules.resolve(["line-length", "no-bare-urls", "-no-bare-urls"]), ["line-length"])
        XCTAssertEqual(LintRules.resolve(["not-a-rule"]), [])
    }

    func testNoRulesMeansNoWork() {
        XCTAssertEqual(lint("# A\n\n#### B  \n", rules: []), [])
    }

    // MARK: heading-increment

    func testHeadingIncrement() {
        let d = lint("# One\n\n### Three\n\n## Two\n", rules: ["heading-increment"])
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(d[0].line, 3)
        XCTAssertTrue(d[0].message.contains("1 to 3"))
    }

    func testFirstHeadingMayStartAnywhere() {
        XCTAssertEqual(lint("### Start\n\n#### Next\n", rules: ["heading-increment"]), [])
    }

    // MARK: no-duplicate-heading

    func testDuplicateHeadings() {
        let d = lint("# A\n\n## Same\n\ntext\n\n## same\n\n### Same\n", rules: ["no-duplicate-heading"])
        XCTAssertEqual(d.map(\.line), [7])   // The ### with the same text is a different level.
    }

    // MARK: no-trailing-spaces

    func testTrailingSpaces() {
        let d = lint("clean\ntrailing   \nhard break  \nnext line\nend \n", rules: ["no-trailing-spaces"])
        XCTAssertEqual(d.map(\.line), [2, 5])
        XCTAssertEqual(d[0].range, NSRange(location: 14, length: 3))
    }

    func testTrailingSpacesInsideCodeAreIgnored() {
        let md = "text\n\n```\ncode   \n```\n\n    indented   \n"
        XCTAssertEqual(lint(md, rules: ["no-trailing-spaces"]), [])
    }

    func testTwoSpacesBeforeBlankLineIsNotAHardBreak() {
        XCTAssertEqual(lint("a  \n\nb\n", rules: ["no-trailing-spaces"]).map(\.line), [1])
    }

    // MARK: list-marker-consistency

    func testListMarkers() {
        let d = lint("- a\n- b\n\ntext\n\n* c\n\ntext\n\n+ d\n", rules: ["list-marker-consistency"])
        XCTAssertEqual(d.map(\.line), [6, 10])
    }

    func testConsistentListsAreFine() {
        XCTAssertEqual(lint("- a\n\ntext\n\n- b\n\n1. one\n2. two\n", rules: ["list-marker-consistency"]), [])
    }

    // MARK: Images and links

    func testMissingAltText() {
        let d = lint("![](a.png) and ![ok](b.png)\n", rules: ["no-missing-alt-text"])
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(d[0].line, 1)
    }

    func testBareUrls() {
        let d = lint("See http://example.com now, <http://ok.com> and [t](http://fine.com).\n", rules: ["no-bare-urls"])
        XCTAssertEqual(d.count, 1)
        XCTAssertEqual(d[0].severity, .info)
        XCTAssertEqual(d[0].range, NSRange(location: 4, length: 18))
    }

    func testBrokenLocalLinks() {
        var options = LintOptions()
        options.baseDirectory = URL(fileURLWithPath: "/docs")
        options.fileExists = { $0.path == "/docs/exists.md" || $0.path == "/docs/img/a b.png" }
        let md = """
        [ok](exists.md) [bad](missing.md) [frag](exists.md#part) [anchor](#top)
        [web](https://x.com) [mail](mailto:a@b.c) ![img](img/a%20b.png) ![gone](gone.png)

        """
        let d = lint(md, rules: ["no-broken-local-links"], options: options)
        XCTAssertEqual(d.count, 2, "\(d)")
        XCTAssertTrue(d[0].message.contains("missing.md"))
        XCTAssertTrue(d[1].message.contains("gone.png"))
    }

    func testBrokenLinkRuleNeedsBaseDirectory() {
        XCTAssertEqual(lint("[x](nope.md)\n", rules: ["no-broken-local-links"]), [])
    }

    func testLinkTargetParsing() {
        XCTAssertNil(LinkTarget.localPath("https://a.com"))
        XCTAssertNil(LinkTarget.localPath("mailto:a@b.c"))
        XCTAssertNil(LinkTarget.localPath("#anchor"))
        XCTAssertNil(LinkTarget.localPath(""))
        XCTAssertNil(LinkTarget.localPath("//cdn.example.com/x"))
        XCTAssertEqual(LinkTarget.localPath("a/b.md#c"), "a/b.md")
        XCTAssertEqual(LinkTarget.localPath("a.md?x=1"), "a.md")
        XCTAssertEqual(LinkTarget.localPath("my%20file.md"), "my file.md")
        XCTAssertEqual(LinkTarget.localPath("/abs/path.md"), "/abs/path.md")
        XCTAssertEqual(LinkTarget.localPath("./rel.md"), "./rel.md")
    }

    // MARK: line-length

    func testLineLength() {
        var options = LintOptions()
        options.maxLineLength = 20
        let md = "short\n" + String(repeating: "x", count: 25) + "\n```\n" + String(repeating: "y", count: 30) + "\n```\nsee http://" + String(repeating: "z", count: 40) + "\n"
        XCTAssertEqual(lint(md, rules: ["line-length"], options: options).map(\.line), [2])
    }

    // MARK: Ranges

    func testRangesAreUTF16() {
        let md = "😀 # not heading\n\n# A\n\n### 😀 Jump  \n"
        let d = lint(md, rules: ["heading-increment", "no-trailing-spaces"])
        let jump = d.first { $0.rule == "heading-increment" }!
        let nsText = md as NSString
        XCTAssertEqual(nsText.substring(with: jump.range), "### 😀 Jump  ")
        let trailing = d.first { $0.rule == "no-trailing-spaces" }!
        XCTAssertEqual(nsText.substring(with: trailing.range), "  ")
    }

    func testCRLFAndEmptyInput() {
        XCTAssertEqual(lint("", rules: LintRules.all), [])
        XCTAssertEqual(lint("a\r\nb   \r\nc\r\n", rules: ["no-trailing-spaces"]).map(\.line), [2])
    }

    func testResultsAreSortedByPosition() {
        let d = lint("# A\n\n### B  \n\n![](x.png)\n")
        XCTAssertEqual(d.map(\.line), d.map(\.line).sorted())
        XCTAssertEqual(Set(names(d)), ["heading-increment", "no-trailing-spaces", "no-missing-alt-text"])
    }

    // MARK: Robustness and speed

    func testStrangeInputDoesNotCrash() {
        for md in ["\0", "[", "![", "```", String(repeating: "#", count: 1000), "\u{FEFF}# a", "[a](" + String(repeating: "(", count: 500)] {
            _ = lint(md)
        }
    }

    func testLargeDocumentIsFast() {
        let block = "## Heading\n\nText with [link](http://example.com) and ![alt](a.png).  \n\n- item\n- item\n\n```\ncode   \n```\n\n"
        let doc = String(repeating: block, count: 12_000)   // About 1 MB.
        let start = Date()
        let d = lint(doc, rules: LintRules.all)
        XCTAssertLessThan(Date().timeIntervalSince(start), 3.0)
        XCTAssertFalse(d.isEmpty)
    }
}
