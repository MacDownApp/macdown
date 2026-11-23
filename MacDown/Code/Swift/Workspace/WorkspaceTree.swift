import Foundation

/// Which files and folders the sidebar shows.
struct WorkspaceOptions {
    /// File extensions that count as Markdown (lower case, no dot).
    var markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mdx"]
    /// Also show `.txt` files.
    var includeText = false
    /// Folders that are never entered. Dot folders are always skipped.
    var ignoredFolderNames: Set<String> = [
        "node_modules", "Pods", ".build", "build", "DerivedData", "vendor", "__pycache__", "target",
    ]

    func isMarkdown(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return markdownExtensions.contains(ext) || (includeText && ext == "txt")
    }
}

struct WorkspaceNode: Equatable, Hashable {
    var url: URL
    var isFolder: Bool
    var name: String { url.lastPathComponent }
}

/// The folder tree behind the sidebar. Shows Markdown files only, and folders
/// only if a Markdown file is somewhere inside them.
///
/// Listing is lazy: one folder at a time, so opening a huge folder costs one
/// directory read. Whether a folder holds Markdown is found by a search that
/// stops at the first match, and the answer is cached until a change is reported.
final class WorkspaceTree {
    let root: URL
    let options: WorkspaceOptions
    private let fileManager = FileManager.default

    private let lock = NSLock()
    private var containsCache: [String: Bool] = [:]

    init(root: URL, options: WorkspaceOptions = WorkspaceOptions()) {
        self.root = root.standardizedFileURL
        self.options = options
    }

    /// Entries of one folder: folders first, then files, each in natural order.
    /// Safe to call from a background queue.
    func children(of folder: URL) -> [WorkspaceNode] {
        var folders: [WorkspaceNode] = []
        var files: [WorkspaceNode] = []
        for entry in entries(in: folder) {
            if entry.isFolder {
                if containsMarkdown(entry.url) { folders.append(WorkspaceNode(url: entry.url, isFolder: true)) }
            } else if options.isMarkdown(entry.url) {
                files.append(WorkspaceNode(url: entry.url, isFolder: false))
            }
        }
        let order: (WorkspaceNode, WorkspaceNode) -> Bool = {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        return folders.sorted(by: order) + files.sorted(by: order)
    }

    /// True if a Markdown file exists somewhere below `folder`. Cached.
    func containsMarkdown(_ folder: URL) -> Bool {
        let key = folder.standardizedFileURL.path
        lock.lock()
        if let cached = containsCache[key] { lock.unlock(); return cached }
        lock.unlock()

        // Breadth-first: files of a level are checked before going deeper, so a
        // match near the top ends the search early.
        var queue = [folder]
        var found = false
        var visited = 0
        search: while !queue.isEmpty, visited < 20_000 {
            let current = queue.removeFirst()
            var subfolders: [URL] = []
            for entry in entries(in: current) {
                visited += 1
                if entry.isFolder { subfolders.append(entry.url) }
                else if options.isMarkdown(entry.url) { found = true; break search }
            }
            queue.append(contentsOf: subfolders)
        }
        lock.lock()
        containsCache[key] = found
        lock.unlock()
        return found
    }

    /// Forget cached answers at and above a changed path. Call this when the
    /// file system watcher reports a change.
    func invalidate(path changed: URL) {
        lock.lock(); defer { lock.unlock() }
        let changedPath = changed.standardizedFileURL.path
        containsCache = containsCache.filter { key, _ in
            !(changedPath == key || changedPath.hasPrefix(key + "/") || key.hasPrefix(changedPath + "/"))
        }
    }

    /// All Markdown files below the root, as paths relative to it. Used for Quick Open.
    /// Stops after `limit` files.
    func allMarkdownFiles(limit: Int = 100_000) -> [String] {
        var result: [String] = []
        // Relative paths are built while walking. Cutting a prefix off absolute
        // paths is wrong: the system may report /private/var for /var.
        var queue: [(url: URL, prefix: String)] = [(root, "")]
        while !queue.isEmpty, result.count < limit {
            let current = queue.removeFirst()
            for entry in entries(in: current.url) {
                let relative = current.prefix + entry.url.lastPathComponent
                if entry.isFolder { queue.append((entry.url, relative + "/")) }
                else if options.isMarkdown(entry.url) {
                    result.append(relative)
                    if result.count >= limit { break }
                }
            }
        }
        return result
    }

    // MARK: Directory reading

    private struct Entry { var url: URL; var isFolder: Bool }

    /// Visible entries of a folder. Skips hidden files, ignored folders and
    /// symbolic links to folders (they could loop).
    private func entries(in folder: URL) -> [Entry] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey]
        guard let urls = try? fileManager.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        var result: [Entry] = []
        result.reserveCapacity(urls.count)
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isDirectory == true {
                if values.isSymbolicLink == true || options.ignoredFolderNames.contains(url.lastPathComponent) { continue }
                result.append(Entry(url: url, isFolder: true))
            } else {
                result.append(Entry(url: url, isFolder: false))
            }
        }
        return result
    }
}
