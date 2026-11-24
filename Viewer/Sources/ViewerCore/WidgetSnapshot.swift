import Foundation

/// A compact picture of the vault for the home screen widgets.
///
/// A widget is a separate process and cannot open the vault folder. So the app writes this snapshot
/// into a container both can read (an App Group), and the widgets only read it.
public struct WidgetSnapshot: Codable, Equatable {
    public struct Note: Codable, Hashable {
        public var path: String
        public var title: String
        /// Seconds since 1970, if known.
        public var modified: Double?
        public init(path: String, title: String, modified: Double?) { self.path = path; self.title = title; self.modified = modified }
        public var folder: String { (path as NSString).deletingLastPathComponent }
        public var modifiedDate: Date? { modified.map { Date(timeIntervalSince1970: $0) } }
    }

    public struct Folder: Codable, Hashable {
        /// Relative path; the vault itself is "".
        public var path: String
        public var name: String
        /// Notes directly in this folder, newest first.
        public var direct: [String]
        /// Notes in this folder and everything below it, newest first.
        public var recent: [String]
        /// Sub-folders that hold notes, the one with the newest note first.
        public var subfolders: [String]
        public init(path: String, name: String, direct: [String], recent: [String], subfolders: [String]) {
            self.path = path; self.name = name; self.direct = direct; self.recent = recent; self.subfolders = subfolders
        }
    }

    public var vaultName: String
    public var generated: Double
    /// The user's accent color (`#rrggbb`), so widgets can match the app. Nil for the default.
    public var accent: String?
    public var notes: [String: Note]
    public var folders: [String: Folder]

    public static let maxNotesPerFolder = 12

    public init(vaultName: String, generated: Double, notes: [String: Note], folders: [String: Folder], accent: String? = nil) {
        self.vaultName = vaultName; self.generated = generated; self.notes = notes; self.folders = folders
        self.accent = accent.flatMap(AccentCSS.normalized)
    }

    // MARK: Building

    public static func build(from index: VaultIndex, vaultName: String, accent: String? = nil, now: Date = Date()) -> WidgetSnapshot {
        var notes: [String: Note] = [:]
        var direct: [String: [String]] = [:]
        var recursive: [String: [String]] = [:]
        var children: [String: Set<String>] = [:]

        for path in index.notes {
            let title = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            notes[path] = Note(path: path, title: title, modified: index.modifiedDate(of: path)?.timeIntervalSince1970)
            let folder = (path as NSString).deletingLastPathComponent
            direct[folder, default: []].append(path)
            // The folder and every folder above it (up to the vault) count this note.
            var current = folder
            recursive[current, default: []].append(path)
            while !current.isEmpty {
                let parent = (current as NSString).deletingLastPathComponent
                children[parent, default: []].insert(current)
                recursive[parent, default: []].append(path)
                current = parent
            }
        }

        func newestFirst(_ paths: [String]) -> [String] {
            paths.sorted { a, b in
                let da = notes[a]?.modified ?? -1, db = notes[b]?.modified ?? -1
                return da != db ? da > db : (notes[a]?.title ?? a).localizedStandardCompare(notes[b]?.title ?? b) == .orderedAscending
            }
        }

        var folders: [String: Folder] = [:]
        for (path, all) in recursive {
            let sortedAll = newestFirst(all)
            let subs = (children[path] ?? []).sorted { a, b in
                let da = notes[recursive[a].flatMap(newestFirst)?.first ?? ""]?.modified ?? -1
                let db = notes[recursive[b].flatMap(newestFirst)?.first ?? ""]?.modified ?? -1
                return da != db ? da > db : a.localizedStandardCompare(b) == .orderedAscending
            }
            folders[path] = Folder(
                path: path,
                name: path.isEmpty ? vaultName : (path as NSString).lastPathComponent,
                direct: Array(newestFirst(direct[path] ?? []).prefix(maxNotesPerFolder)),
                recent: Array(sortedAll.prefix(maxNotesPerFolder)),
                subfolders: subs)
        }
        return WidgetSnapshot(vaultName: vaultName, generated: now.timeIntervalSince1970, notes: notes, folders: folders, accent: accent)
    }

    // MARK: Queries (used by the widget pickers)

    /// The newest notes in the vault.
    public func recentNotes(limit: Int) -> [Note] {
        Array(notes.values.sorted { ($0.modified ?? -1) > ($1.modified ?? -1) }.prefix(limit))
    }

    /// Notes whose title or path contains every word of the query.
    public func searchNotes(_ query: String, limit: Int = 50) -> [Note] {
        let words = query.lowercased().split(separator: " ").map(String.init)
        guard !words.isEmpty else { return recentNotes(limit: limit) }
        return Array(notes.values.filter { note in
            let haystack = note.path.lowercased()
            return words.allSatisfy { haystack.contains($0) }
        }.sorted { ($0.modified ?? -1) > ($1.modified ?? -1) }.prefix(limit))
    }

    /// All folders (including the vault itself), vault first, then by path.
    public var allFolders: [Folder] {
        folders.values.sorted { a, b in
            if a.path.isEmpty != b.path.isEmpty { return a.path.isEmpty }
            return a.path.localizedStandardCompare(b.path) == .orderedAscending
        }
    }
}

// MARK: - What a folder widget shows

public struct WidgetSection: Equatable {
    public var title: String
    public var folderPath: String
    public var notes: [WidgetSnapshot.Note]
    /// Notes that exist for this section but did not fit.
    public var hiddenCount: Int
    public init(title: String, folderPath: String, notes: [WidgetSnapshot.Note], hiddenCount: Int) {
        self.title = title; self.folderPath = folderPath; self.notes = notes; self.hiddenCount = hiddenCount
    }
}

public enum WidgetLayout {
    /// The sections for a folder widget: the folder's own notes, then one section per sub-folder with the
    /// notes below it. `lineBudget` is how many text lines fit (a section title is one line, a note is one).
    /// As many sections as possible get a title and one note; the rest of the lines are shared out.
    public static func sections(for folderPath: String, in snapshot: WidgetSnapshot, lineBudget: Int) -> [WidgetSection] {
        guard let folder = snapshot.folders[folderPath], lineBudget >= 2 else { return [] }

        struct Candidate { var title: String; var path: String; var available: [WidgetSnapshot.Note] }
        func notes(_ paths: [String]) -> [WidgetSnapshot.Note] { paths.compactMap { snapshot.notes[$0] } }

        var candidates: [Candidate] = []
        if !folder.direct.isEmpty {
            candidates.append(Candidate(title: folder.subfolders.isEmpty ? folder.name : "In \(folder.name)", path: folder.path, available: notes(folder.direct)))
        }
        for sub in folder.subfolders {
            if let f = snapshot.folders[sub], !f.recent.isEmpty {
                candidates.append(Candidate(title: f.name, path: f.path, available: notes(f.recent)))
            }
        }

        // First pass: a title and one note each, while lines last.
        var chosen: [(Candidate, Int)] = []
        var remaining = lineBudget
        for candidate in candidates where remaining >= 2 {
            chosen.append((candidate, 1))
            remaining -= 2
        }
        // Second pass: hand out the remaining lines, one note at a time, in order.
        var progressed = true
        while remaining > 0 && progressed {
            progressed = false
            for i in chosen.indices where remaining > 0 && chosen[i].1 < chosen[i].0.available.count {
                chosen[i].1 += 1
                remaining -= 1
                progressed = true
            }
        }
        return chosen.map { candidate, count in
            WidgetSection(title: candidate.title, folderPath: candidate.path,
                          notes: Array(candidate.available.prefix(count)),
                          hiddenCount: max(0, candidate.available.count - count))
        }
    }
}

// MARK: - Sharing between the app and the widgets

/// Reads and writes the snapshot file. The folder is the App Group container, or any folder (tests).
public struct SnapshotStore {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    public static func appGroup() -> SnapshotStore? {
        guard let id = AppGroup.identifier,
              let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else { return nil }
        return SnapshotStore(directory: url)
    }

    private var file: URL { directory.appendingPathComponent("widget-snapshot.json") }

    public func write(_ snapshot: WidgetSnapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: file, options: .atomic)
    }

    /// Nil if there is no snapshot yet or it cannot be read (the widget then asks to open the app).
    public func read() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

public enum AppGroup {
    /// The App Group the app and the widgets share.
    ///
    /// The truth is in the provisioning profile that signed this build (it lists the groups that were
    /// really granted). Signing tools such as AltStore or Sideloadly can rename groups, so the profile is
    /// asked first. Info.plist (`VaultAppGroup`, from the bundle id) is the fallback.
    public static var identifier: String? {
        if let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
           let data = try? Data(contentsOf: url), let group = ProvisioningProfile.appGroups(in: data).first {
            return group
        }
        let value = Bundle.main.object(forInfoDictionaryKey: "VaultAppGroup") as? String
        return (value?.isEmpty == false && value?.contains("$(") == false) ? value : nil
    }
}

public enum ProvisioningProfile {
    /// The App Groups in an `embedded.mobileprovision` file. The file is a signed blob with a plain
    /// property list inside, so the list is cut out of the bytes and read.
    public static func appGroups(in data: Data) -> [String] {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), options: .backwards), start.lowerBound < end.upperBound,
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String] else { return [] }
        return groups.filter { !$0.isEmpty }
    }
}

// MARK: - Links from widgets into the app

public enum DeepLink {
    public static let scheme = "vaultviewer"

    public static func url(forNote path: String) -> URL {
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = "open"
        parts.queryItems = [URLQueryItem(name: "path", value: path)]
        return parts.url ?? URL(string: "\(scheme)://open")!
    }

    /// The note path in a `vaultviewer://open?path=...` link, or nil for anything else.
    public static func notePath(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == "open",
              let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "path" })?.value,
              !path.isEmpty, !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else { return nil }
        return path
    }
}
