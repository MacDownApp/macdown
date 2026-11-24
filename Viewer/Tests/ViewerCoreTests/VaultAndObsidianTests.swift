import XCTest
@testable import ViewerCore

// A resolver backed by a plain list, for syntax tests.
struct FakeVault: VaultResolving {
    var notes: [String] = []
    var files: [String] = []
    func resolveNote(_ target: String, from note: String?) -> String? {
        var name = target
        if let h = name.firstIndex(of: "#") { name = String(name[name.startIndex..<h]) }
        if name.isEmpty { return note }
        return notes.first { ($0 as NSString).deletingPathExtension.lowercased().hasSuffix(name.lowercased()) }
    }
    func resolveAttachment(_ target: String, from note: String?) -> String? {
        files.first { $0.lowercased().hasSuffix(target.lowercased()) }
    }
}

final class VaultIndexTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("vault-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func touch(_ path: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "x".write(to: url, atomically: true, encoding: .utf8)
    }

    func testTreeShowsNotesAndFoldersWithNotesOnly() throws {
        try touch("Inbox.md"); try touch("Projects/Plan.md"); try touch("Projects/img/a.png")
        try touch("Attachments/only.png"); try touch(".obsidian/app.json"); try touch(".trash/Old.md"); try touch("Daily/2024/x.markdown")
        let index = VaultIndex(root: root); index.scan()
        func names(_ nodes: [VaultNode]) -> [String] { nodes.map { $0.isFolder ? "[\($0.name)]" + names($0.children ?? []).joined() : $0.name } }
        XCTAssertEqual(names(index.tree).joined(separator: ","), "[Daily][2024]x,[Projects]Plan,Inbox")
        XCTAssertEqual(index.notes, ["Daily/2024/x.markdown", "Inbox.md", "Projects/Plan.md"])
    }

    func testICloudPlaceholdersAreListedUnderTheirRealNames() throws {
        try touch(".Cloud Note.md.icloud"); try touch("Folder/.Deep.md.icloud"); try touch("Local.md")
        let index = VaultIndex(root: root); index.scan()
        XCTAssertEqual(index.notes, ["Cloud Note.md", "Folder/Deep.md", "Local.md"])
        XCTAssertEqual(index.resolveNote("Cloud Note", from: nil), "Cloud Note.md")
    }

    func testNoteResolutionFollowsObsidianRules() throws {
        try touch("Plan.md"); try touch("Work/Plan.md"); try touch("Work/Deep/Notes.md"); try touch("Other/Notes.md")
        let index = VaultIndex(root: root); index.scan()
        XCTAssertEqual(index.resolveNote("plan", from: nil), "Plan.md", "Shortest path wins")
        XCTAssertEqual(index.resolveNote("Plan", from: "Work/Other.md"), "Work/Plan.md", "Same folder wins")
        XCTAssertEqual(index.resolveNote("Work/Plan", from: nil), "Work/Plan.md")
        XCTAssertEqual(index.resolveNote("Plan.md", from: nil), "Plan.md")
        XCTAssertEqual(index.resolveNote("Notes", from: "Work/Deep/X.md"), "Work/Deep/Notes.md")
        XCTAssertEqual(index.resolveNote("Plan#Heading", from: nil), "Plan.md", "A heading is not part of the name")
        XCTAssertEqual(index.resolveNote("#Heading", from: "Work/Plan.md"), "Work/Plan.md", "Same-note heading link")
        XCTAssertNil(index.resolveNote("Missing", from: nil))
        XCTAssertNil(index.resolveNote("Dan", from: nil), "A name must match whole, not a suffix of another")
    }

    func testAttachmentResolution() throws {
        try touch("a.md"); try touch("img/Diagram.PNG"); try touch("Work/img/Diagram.png"); try touch("doc/Paper.pdf")
        let index = VaultIndex(root: root); index.scan()
        XCTAssertEqual(index.resolveAttachment("diagram.png", from: "a.md"), "img/Diagram.PNG")
        XCTAssertEqual(index.resolveAttachment("Paper.pdf", from: nil), "doc/Paper.pdf")
        XCTAssertEqual(index.resolveAttachment("img/Diagram.PNG", from: nil), "img/Diagram.PNG")
        XCTAssertNil(index.resolveAttachment("missing.png", from: nil))
    }

    func testBigVaultScansQuickly() throws {
        for d in 0..<60 { for f in 0..<50 { try touch("Folder \(d)/Note \(f).\(f % 4 == 0 ? "png" : "md")") } }
        let start = Date()
        let index = VaultIndex(root: root); index.scan()
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
        XCTAssertEqual(index.notes.count, 60 * 37 + 60 * 0 - 0 + (60 * 50 - 60 * 13 - 60 * 37) + 0 + 0 - 0, "notes: \(index.notes.count)")
    }
}

final class ObsidianSyntaxTests: XCTestCase {
    private let vault = FakeVault(notes: ["Projects/Plan.md", "Ideas.md", "Embed Me.md"], files: ["img/pic.png", "audio/a.mp3", "clip.mp4", "doc.pdf"])
    private func run(_ text: String, notes: [String: String] = [:]) -> String {
        ObsidianPreprocessor.process(text, context: ObsidianContext(resolver: vault, note: "Ideas.md", loadNote: { notes[$0] }))
    }

    func testWikilinks() {
        XCTAssertEqual(run("See [[Plan]]."), "See <a class=\"wikilink\" href=\"md://note/Projects/Plan.md\">Plan</a>.")
        XCTAssertTrue(run("[[Plan|the plan]]").contains(">the plan</a>"))
        let heading = run("[[Plan#Next Steps]]")
        XCTAssertTrue(heading.contains("href=\"md://note/Projects/Plan.md#Next%20Steps\""), heading)
        XCTAssertTrue(heading.contains(">Plan &gt; Next Steps</a>"), heading)
        XCTAssertTrue(run("[[#Local]]").contains("href=\"md://note/Ideas.md#Local\""))
        XCTAssertEqual(run("[[Nope]]"), "<span class=\"wikilink unresolved\">Nope</span>")
        XCTAssertTrue(run("[[Plan|<b>x</b>]]").contains("&lt;b&gt;"), "Aliases are escaped")
    }

    func testEmbeds() {
        XCTAssertEqual(run("![[pic.png]]"), "<img src=\"md://vault/img/pic.png\" alt=\"pic.png\">")
        XCTAssertTrue(run("![[pic.png|300]]").contains("width=\"300\""))
        XCTAssertTrue(run("![[pic.png|300x200]]").contains("width=\"300\" height=\"200\""))
        XCTAssertTrue(run("![[pic.png|A caption]]").contains("alt=\"A caption\""))
        XCTAssertTrue(run("![[a.mp3]]").contains("<audio controls src=\"md://vault/audio/a.mp3\">"))
        XCTAssertTrue(run("![[clip.mp4]]").contains("<video controls"))
        XCTAssertTrue(run("![[doc.pdf]]").contains("class=\"embed-file\""))
        XCTAssertEqual(run("![[gone.png]]"), "<span class=\"wikilink unresolved\">gone.png</span>")
        XCTAssertTrue(run("![[my pic.png]]").contains("unresolved"), "Unknown names do not break the page")
    }

    func testPathsAreEncodedInURLs() {
        let v = FakeVault(notes: ["A B/Note 1.md"], files: ["My Images/a b.png"])
        let ctx = ObsidianContext(resolver: v, note: "x.md", loadNote: { _ in nil })
        XCTAssertTrue(ObsidianPreprocessor.process("![[a b.png]]", context: ctx).contains("md://vault/My%20Images/a%20b.png"))
        XCTAssertTrue(ObsidianPreprocessor.process("[[Note 1]]", context: ctx).contains("md://note/A%20B/Note%201.md"))
    }

    func testNoteEmbedShowsTheNoteInline() {
        let out = run("Before\n\n![[Embed Me]]\n\nAfter", notes: ["Embed Me.md": "---\ntitle: x\n---\n# Embedded\n\nBody [[Plan]]"])
        XCTAssertTrue(out.contains("<div class=\"embed-note\">"), out)
        XCTAssertTrue(out.contains("# Embedded"), out)
        XCTAssertTrue(out.contains("href=\"md://note/Projects/Plan.md\""), "Links inside embeds resolve")
        XCTAssertFalse(out.contains("title: x"), "Front matter is not shown")
    }

    func testHeadingSectionEmbed() {
        let note = "# Top\nintro\n## A\nin a\n### A1\nsub\n## B\nin b\n"
        let out = run("![[Embed Me#A]]", notes: ["Embed Me.md": note])
        XCTAssertTrue(out.contains("in a") && out.contains("sub"))
        XCTAssertFalse(out.contains("in b") || out.contains("intro"))
    }

    func testEmbedCyclesAndDepthAreStopped() {
        let notes = ["Embed Me.md": "![[Ideas]]\nself ![[Embed Me]]", "Ideas.md": "![[Embed Me]]"]
        let out = run("![[Embed Me]]", notes: notes)
        XCTAssertLessThan(out.components(separatedBy: "embed-note").count, 6)
    }

    func testCommentsAndTags() {
        XCTAssertEqual(run("a %%hidden%% b"), "a  b")
        XCTAssertEqual(run("a %%multi\nline%% b"), "a  b")
        XCTAssertEqual(run("x %%open only"), "x %%open only")
        XCTAssertEqual(run("Tagged #project/alpha and #todo."), "Tagged <span class=\"tag\">#project/alpha</span> and <span class=\"tag\">#todo</span>.")
        XCTAssertEqual(run("# Heading"), "# Heading")
        XCTAssertEqual(run("Issue #12 and a#b and http://x.com/#frag"), "Issue #12 and a#b and http://x.com/#frag", "Numbers and URL fragments are not tags")
        XCTAssertEqual(run("[link](#anchor)"), "[link](#anchor)")
    }

    func testCodeIsNeverTouched() {
        let text = "`[[Plan]] #tag %%c%%` and\n\n```\n[[Plan]] #tag\n![[pic.png]]\n```\n\n~~~js\n%%x%%\n~~~\n\n``a ` [[Plan]]``\n"
        XCTAssertEqual(run(text), text)
        XCTAssertTrue(run("```\ncode\n```\n[[Plan]]").contains("wikilink"), "Normal text after a fence is processed")
    }

    func testUnicodeAndTrickyInput() {
        XCTAssertTrue(run("日本語 [[Plan]] 🙂 #日本語").contains("wikilink"))
        XCTAssertTrue(run("日本語 #日本語").contains("class=\"tag\""))
        for text in ["[[", "]]", "[[]]", "![[", "![[]]", "%%", "[[a|b|c]]", String(repeating: "[[", count: 500), "`", "```"] { _ = run(text) }
    }

    func testFrontMatterSplit() {
        XCTAssertEqual(FrontMatter.split("---\na: 1\n---\nbody").yaml, "a: 1")
        XCTAssertEqual(FrontMatter.split("---\na: 1\n---\nbody").body, "body")
        XCTAssertNil(FrontMatter.split("no front matter").yaml)
        XCTAssertNil(FrontMatter.split("---\nnever closed").yaml)
        XCTAssertEqual(FrontMatter.split("---\r\na: 1\r\n---\r\nbody").body, "body")
    }
}
