import Foundation

/// A node of the sidebar tree.
public struct VaultNode: Identifiable, Hashable {
    public enum Kind: Hashable { case folder, note, pdf }

    /// Path relative to the vault root, for example `Projects/Plan.md`.
    public let id: String
    public let name: String
    public let kind: Kind
    /// Nil for files. Folders list only what is inside them that holds notes or PDFs.
    public let children: [VaultNode]?

    public var isFolder: Bool { kind == .folder }
}

/// What links can be resolved against: the notes and files of a vault.
public protocol VaultResolving {
    /// Relative path of the note that `[[target]]` means, or nil.
    func resolveNote(_ target: String, from note: String?) -> String?
    /// Relative path of the file that `![[target]]` means (image, PDF, ...), or nil.
    func resolveAttachment(_ target: String, from note: String?) -> String?
}

/// Reads a vault folder once: the tree for the sidebar and the name tables that link
/// resolution needs. Obsidian rules: a link names a note by its file name (without
/// `.md`), optionally with a folder path; the shortest match wins.
///
/// iCloud: a file that is not on the device shows up as a hidden `.Name.ext.icloud`
/// placeholder. It is listed under its real name, so notes can be seen before they are
/// downloaded (opening one downloads it).
///
/// `scan()` reads the file system. Call it off the main thread.
public final class VaultIndex: VaultResolving {
    public let root: URL
    public private(set) var tree: [VaultNode] = []
    /// Relative paths of all notes.
    public private(set) var notes: [String] = []
    /// Relative paths of all PDF files.
    public private(set) var pdfs: [String] = []
    /// Notes and PDFs: everything that can be opened.
    public var documents: [String] { notes + pdfs }

    private var notesByName: [String: [String]] = [:]       // "plan" -> ["Projects/Plan.md"]
    private var filesByName: [String: [String]] = [:]       // "diagram.png" -> ["img/diagram.png"]

    private static let noteExtensions: Set<String> = ["md", "markdown"]
    /// Folders that are not content.
    private static let ignoredFolders: Set<String> = [".obsidian", ".trash", ".git", "node_modules"]

    public init(root: URL) { self.root = root }

    public func scan() {
        var notes: [String] = []
        var pdfs: [String] = []
        var notesByName: [String: [String]] = [:]
        var filesByName: [String: [String]] = [:]

        func list(_ folder: URL, prefix: String) -> [VaultNode] {
            let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
            // Hidden files are included on purpose: iCloud placeholders are hidden.
            guard let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys) else { return [] }
            var folders: [VaultNode] = []
            var files: [VaultNode] = []
            for url in urls {
                var name = url.lastPathComponent
                if name.hasPrefix(".") && name.hasSuffix(".icloud") && name.count > 8 {
                    name = String(name.dropFirst().dropLast(".icloud".count))   // .Note.md.icloud -> Note.md
                } else if name.hasPrefix(".") {
                    continue
                }
                let values = try? url.resourceValues(forKeys: Set(keys))
                let relative = prefix + name
                if values?.isDirectory == true {
                    if values?.isSymbolicLink == true || VaultIndex.ignoredFolders.contains(name) { continue }
                    let children = list(url, prefix: relative + "/")
                    if !children.isEmpty { folders.append(VaultNode(id: relative, name: name, kind: .folder, children: children)) }
                } else {
                    let ext = (name as NSString).pathExtension.lowercased()
                    filesByName[name.lowercased(), default: []].append(relative)
                    if VaultIndex.noteExtensions.contains(ext) {
                        notes.append(relative)
                        let base = (name as NSString).deletingPathExtension.lowercased()
                        notesByName[base, default: []].append(relative)
                        files.append(VaultNode(id: relative, name: (name as NSString).deletingPathExtension, kind: .note, children: nil))
                    } else if ext == "pdf" {
                        pdfs.append(relative)
                        files.append(VaultNode(id: relative, name: name, kind: .pdf, children: nil))
                    }
                }
            }
            let order: (VaultNode, VaultNode) -> Bool = { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return folders.sorted(by: order) + files.sorted(by: order)
        }

        let built = list(root, prefix: "")
        tree = built
        self.notes = notes.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        self.pdfs = pdfs.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        self.notesByName = notesByName
        self.filesByName = filesByName
    }

    /// Notes and PDFs whose path matches a search query, best first.
    public func search(_ query: String, limit: Int = 60) -> [String] {
        FuzzyMatcher.rank(query: query, in: documents, limit: limit)
    }

    // MARK: Resolving

    public func resolveNote(_ target: String, from note: String?) -> String? {
        var name = target.trimmingCharacters(in: .whitespaces)
        if let hash = name.firstIndex(of: "#") { name = String(name[name.startIndex..<hash]) }
        if name.isEmpty { return note }                     // [[#Heading]]: the same note.
        let lower = name.lowercased()
        let withoutExtension = lower.hasSuffix(".md") ? String(lower.dropLast(3)) : lower
        let base = (withoutExtension as NSString).lastPathComponent
        let candidates = notesByName[base] ?? []
        return best(candidates, matching: withoutExtension, from: note) { path in
            String(path.lowercased().dropLast((path as NSString).pathExtension.count + 1))
        }
    }

    public func resolveAttachment(_ target: String, from note: String?) -> String? {
        let name = target.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { return nil }
        let base = (name as NSString).lastPathComponent
        return best(filesByName[base] ?? [], matching: name, from: note) { $0.lowercased() }
    }

    /// Picks among files with the same name: the ones whose path ends with what was written,
    /// then the one in the same folder as the note, then the shortest path.
    private func best(_ candidates: [String], matching written: String, from note: String?,
                      key: (String) -> String) -> String? {
        let matching = candidates.filter { key($0) == written || key($0).hasSuffix("/" + written) }
        guard !matching.isEmpty else { return nil }
        let folder = note.map { ($0 as NSString).deletingLastPathComponent } ?? ""
        return matching.sorted { a, b in
            let sameA = (a as NSString).deletingLastPathComponent == folder
            let sameB = (b as NSString).deletingLastPathComponent == folder
            if sameA != sameB { return sameA }
            return a.count != b.count ? a.count < b.count : a < b
        }.first
    }
}
