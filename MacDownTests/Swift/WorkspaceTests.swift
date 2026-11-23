import XCTest
@testable import MacDown

final class WorkspaceTreeTests: XCTestCase {
    private var root: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appendingPathComponent("macdown-ws-\(UUID().uuidString)").resolvingSymlinksInPath()
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? fm.removeItem(at: root) }

    private func touch(_ path: String, _ content: String = "x") throws {
        let url = root.appendingPathComponent(path)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func names(_ nodes: [WorkspaceNode]) -> [String] { nodes.map { ($0.isFolder ? "[\($0.name)]" : $0.name) } }

    func testShowsOnlyMarkdownFilesAndFoldersWithMarkdown() throws {
        try touch("b.md"); try touch("a.markdown"); try touch("image.png"); try touch("script.js")
        try touch("notes/deep/inside/todo.md")
        try touch("assets/logo.png")
        try touch("empty/readme.txt")
        let tree = WorkspaceTree(root: root)
        XCTAssertEqual(names(tree.children(of: root)), ["[notes]", "a.markdown", "b.md"])
        XCTAssertEqual(names(tree.children(of: root.appendingPathComponent("notes"))), ["[deep]"])
    }

    func testTextFilesAreOptional() throws {
        try touch("readme.txt"); try touch("a.md")
        XCTAssertEqual(names(WorkspaceTree(root: root).children(of: root)), ["a.md"])
        var options = WorkspaceOptions(); options.includeText = true
        XCTAssertEqual(names(WorkspaceTree(root: root, options: options).children(of: root)), ["a.md", "readme.txt"])
    }

    func testHiddenAndIgnoredFoldersAreSkipped() throws {
        try touch(".hidden/secret.md"); try touch(".dotfile.md")
        try touch("node_modules/pkg/README.md"); try touch("Pods/Lib/doc.md")
        try touch("keep/a.md")
        XCTAssertEqual(names(WorkspaceTree(root: root).children(of: root)), ["[keep]"])
    }

    func testSortingIsNaturalWithFoldersFirst() throws {
        for n in ["note10.md", "note2.md", "Note1.md"] { try touch(n) }
        try touch("zeta/a.md"); try touch("Alpha/a.md")
        XCTAssertEqual(names(WorkspaceTree(root: root).children(of: root)),
                       ["[Alpha]", "[zeta]", "Note1.md", "note2.md", "note10.md"])
    }

    func testSymbolicLinksToFoldersAreNotFollowed() throws {
        try touch("real/a.md")
        try fm.createSymbolicLink(at: root.appendingPathComponent("loop"), withDestinationURL: root)
        let tree = WorkspaceTree(root: root)
        XCTAssertEqual(names(tree.children(of: root)), ["[real]"])
        XCTAssertEqual(tree.allMarkdownFiles(), ["real/a.md"])
    }

    func testCacheAndInvalidation() throws {
        try touch("sub/a.txt")
        let tree = WorkspaceTree(root: root)
        let sub = root.appendingPathComponent("sub")
        XCTAssertFalse(tree.containsMarkdown(sub))
        try touch("sub/new.md")
        XCTAssertFalse(tree.containsMarkdown(sub), "Cached answer is kept until invalidated")
        tree.invalidate(path: sub.appendingPathComponent("new.md"))
        XCTAssertTrue(tree.containsMarkdown(sub))
    }

    func testUnreadableOrMissingFolderGivesNoChildren() {
        let tree = WorkspaceTree(root: root)
        XCTAssertEqual(tree.children(of: root.appendingPathComponent("missing")), [])
    }

    func testAllMarkdownFilesAreRelativeAndLimited() throws {
        try touch("a.md"); try touch("d/b.md"); try touch("d/e/c.md"); try touch("d/skip.png")
        let tree = WorkspaceTree(root: root)
        XCTAssertEqual(Set(tree.allMarkdownFiles()), ["a.md", "d/b.md", "d/e/c.md"])
        XCTAssertEqual(tree.allMarkdownFiles(limit: 2).count, 2)
    }

    // MARK: Plan budget: 5,000 files

    func testLargeFolderBudget() throws {
        for d in 0..<100 {
            for f in 0..<50 { try touch("dir\(d)/file\(f).\(f % 5 == 0 ? "md" : "png")", "") }
        }
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: root.path).count, 100)

        let tree = WorkspaceTree(root: root)
        let start = Date()
        let top = tree.children(of: root)
        let listing = Date().timeIntervalSince(start)
        XCTAssertEqual(top.count, 100)
        XCTAssertLessThan(listing, 0.2, "Sidebar must be visible in 200 ms (budget in the plan)")

        let indexStart = Date()
        let all = tree.allMarkdownFiles()
        XCTAssertEqual(all.count, 1000)
        XCTAssertLessThan(Date().timeIntervalSince(indexStart), 1.0)
    }
}

final class FuzzyMatcherTests: XCTestCase {
    func testSubsequenceMatching() {
        XCTAssertNotNil(FuzzyMatcher.score(query: "rdm", candidate: "docs/README.md"))
        XCTAssertNil(FuzzyMatcher.score(query: "xyz", candidate: "docs/README.md"))
        XCTAssertNil(FuzzyMatcher.score(query: "mdr", candidate: "readme.md"))   // Wrong order.
        XCTAssertEqual(FuzzyMatcher.score(query: "", candidate: "anything"), 0)
        XCTAssertEqual(FuzzyMatcher.score(query: "  ", candidate: "anything"), 0)
    }

    func testRankingPrefersFileNamesWordStartsAndShortPaths() {
        let files = ["notes/archive/old-readme-notes.md", "README.md", "docs/read-me-first.md", "src/rendering/engine.md"]
        XCTAssertEqual(FuzzyMatcher.rank(query: "readme", in: files).first, "README.md")
        XCTAssertEqual(FuzzyMatcher.rank(query: "eng", in: files).first, "src/rendering/engine.md")
    }

    func testCaseInsensitiveAndUnicode() {
        XCTAssertNotNil(FuzzyMatcher.score(query: "ÜBER", candidate: "docs/über-uns.md"))
        XCTAssertNotNil(FuzzyMatcher.score(query: "todo", candidate: "TODO.md"))
        XCTAssertNotNil(FuzzyMatcher.score(query: "日本", candidate: "メモ/日本語.md"))
    }

    func testCamelCaseWordStarts() {
        let ranked = FuzzyMatcher.rank(query: "mp", in: ["simple.md", "MyPlan.md"])
        XCTAssertEqual(ranked.first, "MyPlan.md")
    }

    func testRankLimitAndNoMatches() {
        let many = (0..<500).map { "file\($0).md" }
        XCTAssertEqual(FuzzyMatcher.rank(query: "f", in: many, limit: 10).count, 10)
        XCTAssertEqual(FuzzyMatcher.rank(query: "zzz", in: many), [])
    }

    func testFiveThousandCandidatesAreFast() {
        let files = (0..<5000).map { "folder\($0 % 50)/sub\($0 % 7)/document-number-\($0).md" }
        let start = Date()
        let result = FuzzyMatcher.rank(query: "dn42", in: files)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5)
        XCTAssertFalse(result.isEmpty)
    }
}

final class DirectoryWatcherTests: XCTestCase {
    func testReportsNewAndChangedFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("macdown-watch-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let seen = expectation(description: "event")
        seen.assertForOverFulfill = false
        var paths: [String] = []
        let watcher = DirectoryWatcher(root: root, latency: 0.1, queue: .main) { urls in
            paths.append(contentsOf: urls.map(\.lastPathComponent))
            if paths.contains("watched.md") { seen.fulfill() }
        }
        XCTAssertNotNil(watcher)
        // FSEvents needs a moment to start before it sees changes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            try? "hello".write(to: root.appendingPathComponent("watched.md"), atomically: true, encoding: .utf8)
        }
        wait(for: [seen], timeout: 5)
        watcher?.stop()
    }

    func testStopPreventsFurtherEvents() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("macdown-watch-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var called = false
        let watcher = DirectoryWatcher(root: root, latency: 0.05, queue: .main) { _ in called = true }
        watcher?.stop()
        try "x".write(to: root.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        let wait = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { wait.fulfill() }
        self.wait(for: [wait], timeout: 3)
        XCTAssertFalse(called)
    }
}

final class DocumentOutlineTests: XCTestCase {
    func testHeadingsWithLevelsAndLines() {
        let md = "# Title\n\ntext\n\n## Section *one*\n\n### With `code` and [link](x)\n"
        XCTAssertEqual(DocumentOutline.headings(in: md), [
            OutlineItem(level: 1, title: "Title", line: 1),
            OutlineItem(level: 2, title: "Section one", line: 5),
            OutlineItem(level: 3, title: "With code and link", line: 7),
        ])
    }

    func testHeadingsInCodeAreIgnoredAndSetextWorks() {
        let md = "```\n# not a heading\n```\n\nSetext\n======\n\n    # indented code\n"
        XCTAssertEqual(DocumentOutline.headings(in: md), [OutlineItem(level: 1, title: "Setext", line: 5)])
    }

    func testEmptyAndHeadinglessDocuments() {
        XCTAssertEqual(DocumentOutline.headings(in: ""), [])
        XCTAssertEqual(DocumentOutline.headings(in: "just text"), [])
    }
}
