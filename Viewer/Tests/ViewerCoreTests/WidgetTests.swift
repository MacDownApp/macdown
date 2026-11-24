import XCTest
@testable import ViewerCore

final class WidgetSnapshotTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("wvault-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    /// Creates a note whose modification time is `daysAgo` days in the past.
    private func note(_ path: String, daysAgo: Double) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "x".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-daysAgo * 86400)], ofItemAtPath: url.path)
    }

    private func snapshot() -> WidgetSnapshot {
        let index = VaultIndex(root: root); index.scan()
        return WidgetSnapshot.build(from: index, vaultName: "My Vault")
    }

    func testFoldersNotesAndOrder() throws {
        try note("Root old.md", daysAgo: 30); try note("Root new.md", daysAgo: 1)
        try note("Work/Plan.md", daysAgo: 5); try note("Work/Deep/Idea.md", daysAgo: 2); try note("Work/Deep/Older.md", daysAgo: 9)
        try note("Home/Chores.md", daysAgo: 20)
        let s = snapshot()

        let top = try XCTUnwrap(s.folders[""])
        XCTAssertEqual(top.name, "My Vault")
        XCTAssertEqual(top.direct, ["Root new.md", "Root old.md"], "Newest first")
        XCTAssertEqual(top.recent.first, "Root new.md")
        XCTAssertEqual(top.recent.count, 6)
        XCTAssertEqual(top.subfolders, ["Work", "Home"], "The folder with the newest note comes first")

        let work = try XCTUnwrap(s.folders["Work"])
        XCTAssertEqual(work.direct, ["Work/Plan.md"])
        XCTAssertEqual(work.recent, ["Work/Deep/Idea.md", "Work/Plan.md", "Work/Deep/Older.md"])
        XCTAssertEqual(work.subfolders, ["Work/Deep"])
        XCTAssertEqual(s.folders["Work/Deep"]?.name, "Deep")
        XCTAssertEqual(s.notes["Work/Plan.md"]?.title, "Plan")
        XCTAssertEqual(s.notes["Work/Plan.md"]?.folder, "Work")
        XCTAssertNotNil(s.notes["Work/Plan.md"]?.modifiedDate)
    }

    func testCapsKeepTheSnapshotSmall() throws {
        for i in 0..<40 { try note("Big/Note \(i).md", daysAgo: Double(i)) }
        let s = snapshot()
        XCTAssertEqual(s.folders["Big"]?.direct.count, WidgetSnapshot.maxNotesPerFolder)
        XCTAssertEqual(s.folders["Big"]?.recent.first, "Big/Note 0.md")
        XCTAssertEqual(s.notes.count, 40, "Every note stays pickable")
    }

    func testPickerQueries() throws {
        try note("A/Alpha plan.md", daysAgo: 3); try note("B/Beta.md", daysAgo: 1); try note("B/Alpha notes.md", daysAgo: 2)
        let s = snapshot()
        XCTAssertEqual(s.recentNotes(limit: 2).map(\.path), ["B/Beta.md", "B/Alpha notes.md"])
        XCTAssertEqual(s.searchNotes("alpha").map(\.path), ["B/Alpha notes.md", "A/Alpha plan.md"])
        XCTAssertEqual(s.searchNotes("alpha b/").map(\.path), ["B/Alpha notes.md"], "Words match the path too")
        XCTAssertEqual(s.searchNotes("").count, 3)
        XCTAssertEqual(s.searchNotes("zzz"), [])
        XCTAssertEqual(s.allFolders.map(\.path), ["", "A", "B"])
    }

    func testEmptyVault() {
        let s = snapshot()
        XCTAssertTrue(s.notes.isEmpty)
        XCTAssertTrue(WidgetLayout.sections(for: "", in: s, lineBudget: 10).isEmpty)
    }

    func testStoreRoundTripAndBadFiles() throws {
        try note("N.md", daysAgo: 1)
        let store = SnapshotStore(directory: root.appendingPathComponent("shared"))
        XCTAssertNil(store.read(), "No file yet")
        let s = snapshot()
        try store.write(s)
        XCTAssertEqual(store.read(), s)
        try store.write(s)    // Overwriting works.
        try Data("not json".utf8).write(to: root.appendingPathComponent("shared/widget-snapshot.json"))
        XCTAssertNil(store.read(), "A damaged file must not crash the widget")
    }

    func testBigVaultSnapshotIsQuickAndSmall() throws {
        for f in 0..<80 { for n in 0..<25 { try note("F\(f)/N\(n).md", daysAgo: Double(f + n)) } }   // 2,000 notes
        let start = Date()
        let s = snapshot()
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
        let size = try JSONEncoder().encode(s).count
        XCTAssertLessThan(size, 1_500_000, "Widgets have little memory: \(size) bytes")
    }
}

final class WidgetLayoutTests: XCTestCase {
    private func vault() -> WidgetSnapshot {
        func n(_ p: String, _ d: Double) -> WidgetSnapshot.Note {
            WidgetSnapshot.Note(path: p, title: ((p as NSString).lastPathComponent as NSString).deletingPathExtension, modified: d)
        }
        let notes = [n("Top 1.md", 100), n("Top 2.md", 90),
                     n("A/a1.md", 80), n("A/a2.md", 70), n("A/a3.md", 60),
                     n("B/b1.md", 50), n("B/b2.md", 40),
                     n("C/c1.md", 30)]
        var map: [String: WidgetSnapshot.Note] = [:]
        for note in notes { map[note.path] = note }
        let folders: [String: WidgetSnapshot.Folder] = [
            "": .init(path: "", name: "Vault", direct: ["Top 1.md", "Top 2.md"], recent: notes.map(\.path), subfolders: ["A", "B", "C"]),
            "A": .init(path: "A", name: "A", direct: ["A/a1.md", "A/a2.md", "A/a3.md"], recent: ["A/a1.md", "A/a2.md", "A/a3.md"], subfolders: []),
            "B": .init(path: "B", name: "B", direct: ["B/b1.md", "B/b2.md"], recent: ["B/b1.md", "B/b2.md"], subfolders: []),
            "C": .init(path: "C", name: "C", direct: ["C/c1.md"], recent: ["C/c1.md"], subfolders: []),
        ]
        return WidgetSnapshot(vaultName: "Vault", generated: 0, notes: map, folders: folders)
    }

    func testLargeShowsEverySectionWithMoreNotes() {
        let sections = WidgetLayout.sections(for: "", in: vault(), lineBudget: 12)
        XCTAssertEqual(sections.map(\.title), ["In Vault", "A", "B", "C"])
        XCTAssertEqual(sections.map(\.notes.count), [2, 3, 2, 1])
        XCTAssertEqual(sections.map(\.hiddenCount), [0, 0, 0, 0])
        XCTAssertLessThanOrEqual(sections.reduce(0) { $0 + 1 + $1.notes.count }, 12, "Never more lines than fit")
    }

    func testMediumSharesAFewLinesBetweenSections() {
        // 7 lines: three sections get a title and a note (6 lines); the extra line goes to the first.
        let sections = WidgetLayout.sections(for: "", in: vault(), lineBudget: 7)
        XCTAssertEqual(sections.map(\.title), ["In Vault", "A", "B"])
        XCTAssertEqual(sections.map(\.notes.count), [2, 1, 1])
        XCTAssertEqual(sections.map(\.hiddenCount), [0, 2, 1])
        XCTAssertLessThanOrEqual(sections.reduce(0) { $0 + 1 + $1.notes.count }, 7)
        // 6 lines: still three sections, one note each.
        XCTAssertEqual(WidgetLayout.sections(for: "", in: vault(), lineBudget: 6).map(\.notes.count), [1, 1, 1])
        XCTAssertEqual(WidgetLayout.sections(for: "", in: vault(), lineBudget: 3).map(\.title), ["In Vault"])
    }

    func testChoosingASubfolderShowsItsOwnSections() {
        let sections = WidgetLayout.sections(for: "A", in: vault(), lineBudget: 8)
        XCTAssertEqual(sections.map(\.title), ["A"], "No sub-folders: one section")
        XCTAssertEqual(sections.first?.notes.map(\.title), ["a1", "a2", "a3"])
    }

    func testTinyBudgetsAndUnknownFolders() {
        XCTAssertTrue(WidgetLayout.sections(for: "", in: vault(), lineBudget: 1).isEmpty)
        XCTAssertEqual(WidgetLayout.sections(for: "", in: vault(), lineBudget: 2).count, 1)
        XCTAssertTrue(WidgetLayout.sections(for: "Nope", in: vault(), lineBudget: 10).isEmpty)
    }
}

final class DeepLinkTests: XCTestCase {
    func testRoundTripWithAwkwardNames() {
        for path in ["Note.md", "Folder/Sub folder/Ünï & more #1?.md", "日本語/メモ.md"] {
            let url = DeepLink.url(forNote: path)
            XCTAssertEqual(url.scheme, "vaultviewer")
            XCTAssertEqual(DeepLink.notePath(from: url), path, url.absoluteString)
        }
    }

    func testOnlyOurLinksAndSafePathsAreAccepted() {
        XCTAssertNil(DeepLink.notePath(from: URL(string: "https://example.com/open?path=a.md")!))
        XCTAssertNil(DeepLink.notePath(from: URL(string: "vaultviewer://other?path=a.md")!))
        XCTAssertNil(DeepLink.notePath(from: URL(string: "vaultviewer://open")!))
        XCTAssertNil(DeepLink.notePath(from: URL(string: "vaultviewer://open?path=")!))
        XCTAssertNil(DeepLink.notePath(from: URL(string: "vaultviewer://open?path=/etc/passwd")!))
        XCTAssertNil(DeepLink.notePath(from: URL(string: "vaultviewer://open?path=a/../../b.md")!))
    }

    func testAppGroupsAreReadFromAProvisioningProfile() {
        func profile(_ entitlements: String) -> Data {
            // Signed profiles wrap the property list in binary data.
            var data = Data([0x30, 0x82, 0x0A, 0xFF, 0x06, 0x09, 0x2A, 0x86, 0x00, 0x01, 0x3C])
            data.append(Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <plist version="1.0"><dict><key>Name</key><string>iOS Team Provisioning Profile</string>
            <key>Entitlements</key><dict>\(entitlements)</dict></dict></plist>
            """.utf8))
            data.append(Data([0x00, 0xFF, 0x13, 0x37, 0x80]))
            return data
        }
        XCTAssertEqual(ProvisioningProfile.appGroups(in: profile("<key>com.apple.security.application-groups</key><array><string>group.ABCDE.me.viewer</string><string>group.other</string></array>")),
                       ["group.ABCDE.me.viewer", "group.other"])
        XCTAssertEqual(ProvisioningProfile.appGroups(in: profile("<key>get-task-allow</key><true/>")), [], "No groups granted")
        XCTAssertEqual(ProvisioningProfile.appGroups(in: Data("garbage".utf8)), [])
        XCTAssertEqual(ProvisioningProfile.appGroups(in: Data()), [])
        XCTAssertEqual(ProvisioningProfile.appGroups(in: Data("<?xml </plist> <?xml".utf8)), [])
    }

    func testAppGroupIdentifierIgnoresUnexpandedValues() {
        // In the test bundle the key is absent: no group, so widgets say "open the app".
        XCTAssertNil(AppGroup.identifier)
    }
}
