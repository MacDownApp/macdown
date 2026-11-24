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

final class ThemePaletteTests: XCTestCase {
    private var folder: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("MacDown/Resources/BuiltinThemes")
    }

    private func luminance(_ c: ThemeColor) -> Double {
        func f(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(c.red) + 0.7152 * f(c.green) + 0.0722 * f(c.blue)
    }

    private func contrast(_ a: ThemeColor, _ b: ThemeColor) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    func testEveryThemeFileParsesAndIsReadable() throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".yaml") }
        let loaded = ThemeCatalog.load(from: folder)
        XCTAssertEqual(loaded.count, files.count, "A theme file failed to parse: \(files.count) files, \(loaded.count) themes")
        for name in ["Ayu Light", "Ayu Mirage", "Ayu Dark", "Catppuccin Latte", "Catppuccin Frappe", "Catppuccin Macchiato",
                     "Catppuccin Mocha", "Full Black", "Full White", "E-Paper"] {
            XCTAssertTrue(loaded.contains { $0.name == name }, "Missing theme \(name)")
        }
        // Well-known palettes from before this check, kept as their authors made them (low contrast by design).
        let knownLowContrast: Set<String> = ["Solarized Light", "Solarized Dark"]
        for file in files {
            let theme = try Theme.parse(yaml: String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8))
            let v = theme.variant(isDark: false)
            let legacy = knownLowContrast.contains(theme.name)
            XCTAssertGreaterThanOrEqual(contrast(v.preview.text, v.preview.background), legacy ? 4.0 : 4.5, "\(theme.name): body text contrast")
            for key in ["heading", "link", "keyword", "string"] where !legacy {
                if let c = v.tokens[key]?.color {
                    XCTAssertGreaterThanOrEqual(contrast(c, v.preview.background), 3, "\(theme.name): \(key) is hard to read")
                }
            }
        }
    }

    func testFullBlackAndWhiteAreExact() throws {
        let themes = ThemeCatalog.load(from: folder)
        XCTAssertEqual(themes.first { $0.name == "Full Black" }?.backgroundHex(systemDark: false), "#000000")
        XCTAssertEqual(themes.first { $0.name == "Full White" }?.backgroundHex(systemDark: false), "#ffffff")
        XCTAssertTrue(themes.first { $0.name == "Full Black" }!.isDark(systemDark: false))
        XCTAssertFalse(themes.first { $0.name == "Full White" }!.isDark(systemDark: true))
    }

    func testEPaperHasNoColor() throws {
        let theme = try Theme.parse(yaml: String(contentsOf: folder.appendingPathComponent("E-Paper.yaml"), encoding: .utf8))
        let v = theme.variant(isDark: false)
        func isGray(_ c: ThemeColor) -> Bool { abs(c.red - c.green) < 0.03 && abs(c.green - c.blue) < 0.03 }
        for (key, style) in v.tokens { if let c = style.color { XCTAssertTrue(isGray(c), "E-Paper token \(key) has color") } }
        XCTAssertTrue(v.tokens["keyword"]?.bold == true, "Without color, bold carries meaning")
    }
}

final class AccentTests: XCTestCase {
    func testValidColorsMakeCSS() {
        let css = AccentCSS.css(hex: "#a259e6")
        XCTAssertTrue(css.contains("html body a, html body a.wikilink { color: #a259e6; }"), css)
        XCTAssertTrue(css.contains("html body .tag { color: #a259e6; background: rgba(162, 89, 230, 0.18); }"), css)
        XCTAssertTrue(css.contains("accent-color: #a259e6"))
        XCTAssertTrue(css.contains("::selection { background: rgba(162, 89, 230, 0.3); }"), css)
    }

    func testShortAndUppercaseHexAreNormalized() {
        XCTAssertEqual(AccentCSS.normalized("#F80"), "#ff8800")
        XCTAssertEqual(AccentCSS.normalized("#A259E6"), "#a259e6")
        XCTAssertTrue(AccentCSS.css(hex: "#f80").contains("#ff8800"))
    }

    func testNoAccentOrBadInputMeansNoCSS() {
        for bad in ["", "red", "a259e6", "#12", "#gggggg", "#a259e6; } body { display: none } /*", "#a259e680", "url(x)"] {
            XCTAssertEqual(AccentCSS.css(hex: bad), "", "\(bad)")
            XCTAssertNil(AccentCSS.normalized(bad), "\(bad)")
        }
    }

    func testEveryPresetIsValid() {
        XCTAssertGreaterThanOrEqual(AccentCSS.presets.count, 8)
        for preset in AccentCSS.presets { XCTAssertEqual(AccentCSS.normalized(preset.hex), preset.hex, preset.name) }
        XCTAssertEqual(Set(AccentCSS.presets.map(\.hex)).count, AccentCSS.presets.count, "No duplicate colors")
    }

    func testOnAccentColor() {
        XCTAssertTrue(AccentCSS.onAccentIsDark("#ffd60a"), "Dark text on yellow")
        XCTAssertFalse(AccentCSS.onAccentIsDark("#5e5ce6"), "White text on indigo")
        XCTAssertFalse(AccentCSS.onAccentIsDark("nonsense"))
    }

    func testPageUsesTheAccentLast() {
        let note = NoteRenderer.render(markdown: "[[x]] #tag", notePath: "n.md", resolver: FakeVault(), loadNote: { _ in nil })
        let page = ViewerPage.html(note: note, title: "T", themeCSS: "/*theme*/", fontCSS: "/*font*/", accentCSS: AccentCSS.css(hex: "#30b350"))
        XCTAssertLessThan(page.range(of: "/*theme*/")!.lowerBound, page.range(of: "/*font*/")!.lowerBound)
        XCTAssertLessThan(page.range(of: "/*font*/")!.lowerBound, page.range(of: "#30b350")!.lowerBound)
        XCTAssertFalse(ViewerPage.html(note: note, title: "T", themeCSS: "").contains("accent-color"), "No accent: nothing added")
    }

    func testSnapshotCarriesTheAccentAndOldSnapshotsStillLoad() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("acc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "x".write(to: root.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        let index = VaultIndex(root: root); index.scan()

        let withAccent = WidgetSnapshot.build(from: index, vaultName: "V", accent: "#FF453A")
        XCTAssertEqual(withAccent.accent, "#ff453a")
        XCTAssertEqual(try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(withAccent)).accent, "#ff453a")
        XCTAssertNil(WidgetSnapshot.build(from: index, vaultName: "V").accent)
        XCTAssertNil(WidgetSnapshot.build(from: index, vaultName: "V", accent: "javascript:alert(1)").accent, "Invalid colors are dropped")

        // A snapshot written by the previous version has no "accent" key.
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(withAccent)) as! [String: Any]
        object.removeValue(forKey: "accent")
        let old = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(old.accent)
        XCTAssertEqual(old.notes.count, 1)
    }
}
