import XCTest
import PDFKit
@testable import ViewerCore

final class PDFTests: XCTestCase {
    /// A real PDF with `pages` pages, made with Core Graphics.
    private func makePDF(pages: Int) -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 300, height: 400)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, nil)!
        for _ in 0..<pages {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
            context.fill(CGRect(x: 20, y: 20, width: 100, height: 100))
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    func testPageFragments() {
        XCTAssertEqual(PDFLink.page(fromFragment: "page=3"), 3)
        XCTAssertEqual(PDFLink.page(fromFragment: "page=12&zoom=100"), 12)
        XCTAssertEqual(PDFLink.page(fromFragment: "zoom=50,page=2"), 2)
        XCTAssertEqual(PDFLink.page(fromFragment: "PAGE=4"), 4)
        XCTAssertEqual(PDFLink.page(fromFragment: "5"), 5)
        XCTAssertEqual(PDFLink.page(fromFragment: "page%3D6"), 6, "Percent-encoded")
        for bad in ["", "page=0", "page=-1", "page=x", "heading", "page="] { XCTAssertNil(PDFLink.page(fromFragment: bad), bad) }
    }

    func testValidPDFOpens() throws {
        let doc = try PDFLoader.open(makePDF(pages: 3)).get()
        XCTAssertEqual(doc.pageCount, 3)
    }

    func testBadInputIsRefusedWithAClearReason() throws {
        XCTAssertEqual(PDFLoader.open(Data("not a pdf".utf8)).failureValue, .notAPDF)
        XCTAssertEqual(PDFLoader.open(Data()).failureValue, .notAPDF)
        XCTAssertTrue(PDFLoader.message(for: .notReadable, name: "a.pdf").contains("iCloud"))
        XCTAssertTrue(PDFLoader.message(for: .locked, name: "a.pdf").contains("password"))
    }

    func testLoadingFromDiskThroughTheCoordinator() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pdf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try makePDF(pages: 2).write(to: dir.appendingPathComponent("a.pdf"))
        XCTAssertEqual(try PDFLoader.load(dir.appendingPathComponent("a.pdf")).get().pageCount, 2)
        XCTAssertEqual(PDFLoader.load(dir.appendingPathComponent("missing.pdf")).failureValue, .notReadable)
        XCTAssertEqual(PDFLoader.load(dir).failureValue, .notReadable, "A folder is not a PDF")
    }

    func testPDFsAreServedToThePageOnlyAsFilesNotCards() {
        // The embed is a link card; the PDF itself is opened by the app, not drawn inside the page.
        let card = ObsidianPreprocessor.process("![[a.pdf]]", context: ObsidianContext(
            resolver: FakeVault(files: ["a.pdf"]), note: "n.md", loadNote: { _ in nil }))
        XCTAssertFalse(card.contains("<iframe") || card.contains("<embed") || card.contains("<object"))
    }
}

private extension Result {
    var failureValue: Failure? { if case let .failure(e) = self { return e }; return nil }
}
