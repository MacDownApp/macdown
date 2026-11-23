import XCTest
@testable import MacDown

final class MarkdownExtensionMaskerTests: XCTestCase {
    private func all() -> MarkdownExtensions {
        MarkdownExtensions(math: true, mathInlineDollar: true, highlight: true,
                           superscript: true, underline: true, quote: true)
    }

    /// Masks, then restores. With no parser in between, this shows the markup
    /// the extensions produce.
    private func roundTrip(_ source: String, _ ext: MarkdownExtensions? = nil) -> String {
        let masked = MarkdownExtensionMasker.mask(source, extensions: ext ?? all())
        return masked.unmask(masked.text)
    }

    // MARK: Highlight

    func testHighlight() {
        XCTAssertEqual(roundTrip("a ==b== c"), "a <mark>b</mark> c")
        XCTAssertEqual(roundTrip("==a== and ==b=="), "<mark>a</mark> and <mark>b</mark>")
        XCTAssertEqual(roundTrip("==*em* text=="), "<mark>*em* text</mark>")
    }

    func testHighlightNeedsMatchingAndTextAroundDelimiters() {
        XCTAssertEqual(roundTrip("a == b"), "a == b")
        XCTAssertEqual(roundTrip("a ==b"), "a ==b")
        XCTAssertEqual(roundTrip("x == y == z"), "x == y == z")
        XCTAssertEqual(roundTrip("a === b"), "a === b")
    }

    // MARK: Code is never touched

    func testInlineCodeIsProtected() {
        XCTAssertEqual(roundTrip("`==x==` and `$a$` and `^2`"), "`==x==` and `$a$` and `^2`")
        XCTAssertEqual(roundTrip("``a ` ==b== ``"), "``a ` ==b== ``")
    }

    func testFencedCodeIsProtected() {
        let md = "before ==a==\n\n```\n==b== $c$\n```\n\nafter ==d=="
        XCTAssertEqual(roundTrip(md), "before <mark>a</mark>\n\n```\n==b== $c$\n```\n\nafter <mark>d</mark>")
        let tilde = "~~~python\n_x_ ==y==\n~~~\n"
        XCTAssertEqual(roundTrip(tilde), tilde)
        let quoted = "> ```\n> ==x==\n> ```\n"
        XCTAssertEqual(roundTrip(quoted), quoted)
    }

    func testIndentedCodeIsProtected() {
        let md = "text\n\n    ==code== $x$\n\n==real=="
        XCTAssertEqual(roundTrip(md), "text\n\n    ==code== $x$\n\n<mark>real</mark>")
    }

    func testListContinuationIsNotCode() {
        let md = "- item\n\n    more ==text== here\n"
        XCTAssertEqual(roundTrip(md), "- item\n\n    more <mark>text</mark> here\n")
    }

    func testLinkDestinationsHtmlAndReferencesAreProtected() {
        XCTAssertEqual(roundTrip("[a](http://x.com/==y==_z_)"), "[a](http://x.com/==y==_z_)")
        XCTAssertEqual(roundTrip("<a href=\"x_y_z\" title=\"==t==\">"), "<a href=\"x_y_z\" title=\"==t==\">")
        XCTAssertEqual(roundTrip("[ref]: http://x.com/_a_b_\n\n_u_"), "[ref]: http://x.com/_a_b_\n\n<u>u</u>")
    }

    // MARK: Underline

    func testUnderline() {
        XCTAssertEqual(roundTrip("a _b c_ d"), "a <u>b c</u> d")
        XCTAssertEqual(roundTrip("snake_case_word"), "snake_case_word")
        XCTAssertEqual(roundTrip("__strong__"), "__strong__")
        XCTAssertEqual(roundTrip("_open only"), "_open only")
        XCTAssertEqual(roundTrip("_a_."), "<u>a</u>.")
    }

    // MARK: Superscript

    func testSuperscript() {
        XCTAssertEqual(roundTrip("x^2"), "x<sup>2</sup>")
        XCTAssertEqual(roundTrip("x^(a+b) z"), "x<sup>a+b</sup> z")
        XCTAssertEqual(roundTrip("H^2^O"), "H<sup>2</sup>O")
        XCTAssertEqual(roundTrip("2^10."), "2<sup>10</sup>.")
        XCTAssertEqual(roundTrip("a ^ b"), "a ^ b")
        XCTAssertEqual(roundTrip("x^(f(y)) end"), "x<sup>f(y)</sup> end")
    }

    // MARK: Quote

    func testQuote() {
        XCTAssertEqual(roundTrip("say \"hi there\" now"), "say <q>hi there</q> now")
        XCTAssertEqual(roundTrip("lone \" mark"), "lone \" mark")
    }

    // MARK: Math

    func testInlineDollarMath() {
        XCTAssertEqual(roundTrip("a $x^2 + y_1$ b"), "a \\(x^2 + y_1\\) b")
    }

    func testCurrencyIsNotMath() {
        XCTAssertEqual(roundTrip("Price is $5 and $10 total."), "Price is $5 and $10 total.")
        XCTAssertEqual(roundTrip("It costs $5."), "It costs $5.")
        XCTAssertEqual(roundTrip("$ 5 and 6 $"), "$ 5 and 6 $")
        XCTAssertEqual(roundTrip("from $a$5"), "from $a$5")
    }

    func testDisplayMath() {
        XCTAssertEqual(roundTrip("$$a<b$$"), "\\[a&lt;b\\]")
        XCTAssertEqual(roundTrip("$$\n\\int_0^1 x\\,dx\n$$"), "\\[\n\\int_0^1 x\\,dx\n\\]")
    }

    func testExplicitMathDelimiters() {
        XCTAssertEqual(roundTrip("\\(x_i\\) and \\[y^2\\]"), "\\(x_i\\) and \\[y^2\\]")
    }

    func testEscapedDollarAndDisabledOptions() {
        XCTAssertEqual(roundTrip("\\$5 and \\$6"), "\\$5 and \\$6")
        var ext = all()
        ext.mathInlineDollar = false
        XCTAssertEqual(roundTrip("$x$", ext), "$x$")
        ext.math = false
        XCTAssertEqual(roundTrip("\\(x\\) $$y$$", ext), "\\(x\\) $$y$$")
    }

    func testMarkersInsideMathAreNotProcessed() {
        XCTAssertEqual(roundTrip("$a==b$ and $x^2$"), "\\(a==b\\) and \\(x^2\\)")
    }

    func testMathInsideOtherSpans() {
        XCTAssertEqual(roundTrip("==$x$=="), "<mark>\\(x\\)</mark>")
    }

    // MARK: Robustness

    func testUnicodeText() {
        XCTAssertEqual(roundTrip("日本語 ==テスト== 終わり"), "日本語 <mark>テスト</mark> 終わり")
        XCTAssertEqual(roundTrip("é_a_é"), "é_a_é")
    }

    func testNoExtensionsLeavesTextAlone() {
        let md = "==a== _b_ $c$ ^d"
        XCTAssertEqual(MarkdownExtensionMasker.mask(md, extensions: MarkdownExtensions()).text, md)
    }

    func testSourceWithPlaceholderCharactersIsLeftAlone() {
        let md = "==a== \u{E000} \u{E011}"
        XCTAssertEqual(roundTrip(md), md)
    }

    func testEmptyAndTinyInputs() {
        for md in ["", "=", "==", "$", "$$", "^", "_", "\"", "\\", "`", "<", "]", "]("] {
            XCTAssertNoThrow(roundTrip(md))
        }
    }

    func testPathologicalInputIsFast() {
        let inputs = [
            String(repeating: "== ", count: 100_000),
            String(repeating: "$$ ", count: 100_000),
            String(repeating: "$a ", count: 100_000),
            String(repeating: "_a ", count: 100_000),
            String(repeating: "^(", count: 100_000),
            String(repeating: "\\(", count: 100_000),
            String(repeating: "`", count: 100_001),
        ]
        for input in inputs {
            let start = Date()
            _ = MarkdownExtensionMasker.mask(input, extensions: all())
            XCTAssertLessThan(Date().timeIntervalSince(start), 2.0, "Slow for \(input.prefix(6))")
        }
    }

    func testLargeDocumentIsFast() {
        let block = "Paragraph with ==marked== text, _under_, x^2, and $a+b$ math.\n\n```\ncode ==x==\n```\n\n"
        let doc = String(repeating: block, count: 12_000)   // About 1 MB.
        let start = Date()
        let masked = MarkdownExtensionMasker.mask(doc, extensions: all())
        let restored = masked.unmask(masked.text)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
        XCTAssertTrue(restored.contains("<mark>marked</mark>"))
        XCTAssertTrue(restored.contains("code ==x=="))
    }
}
