import SwiftUI
import PDFKit
import WidgetKit
import ViewerCore

/// Holds the open vault: the folder (kept by a security-scoped bookmark), its index, and the
/// note that is open. Everything slow (scanning, reading, rendering) runs off the main thread.
@MainActor
final class VaultStore: ObservableObject {
    @Published private(set) var vaultName: String?
    @Published private(set) var tree: [VaultNode] = []
    @Published private(set) var selectedPath: String?
    @Published private(set) var note: RenderedNote?
    @Published private(set) var noteTitle = ""
    /// Heading to scroll to after the note loads.
    @Published private(set) var scrollTarget: String?
    /// The open PDF, if a PDF (not a note) is shown.
    @Published private(set) var pdf: PDFItem?
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?

    /// Shared with the web view's file handler, which asks for the folder on every request.
    let rootBox = RootBox()
    private(set) var index: VaultIndex?

    private let bookmarkKey = "vaultBookmark"
    private let lastNoteKey = "lastNote"
    private var accessedURL: URL?
    private var openToken = 0
    /// A note asked for by a link (a widget) before the vault finished loading.
    private var pendingOpen: String?

    final class RootBox { var url: URL? }

    struct PDFItem {
        let path: String
        let document: PDFDocument
        /// 1-based page to show first.
        let page: Int
        var name: String { (path as NSString).lastPathComponent }
    }

    init() { restore() }

    // MARK: Choosing and restoring the vault

    func chooseVault(_ url: URL) {
        stopAccess()
        guard url.startAccessingSecurityScopedResource() else {
            message = "The folder could not be opened. Choose it again."
            return
        }
        accessedURL = url
        if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }
        UserDefaults.standard.removeObject(forKey: lastNoteKey)
        selectedPath = nil
        note = nil
        message = nil
        load(url: url, reopenLast: false)
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale),
              url.startAccessingSecurityScopedResource() else {
            message = "The vault folder is not available any more. Choose it again."
            return
        }
        accessedURL = url
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: bookmarkKey)
        }
        load(url: url, reopenLast: true)
    }

    private func stopAccess() {
        accessedURL?.stopAccessingSecurityScopedResource()
        accessedURL = nil
    }

    // MARK: Scanning

    private func load(url: URL, reopenLast: Bool) {
        vaultName = url.lastPathComponent
        rootBox.url = url
        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let index = VaultIndex(root: url)
            index.scan()
            await self?.finishScan(index, reopenLast: reopenLast)
        }
    }

    private func finishScan(_ index: VaultIndex, reopenLast: Bool) {
        self.index = index
        tree = index.tree
        isLoading = false
        publishToWidgets(index)
        if let pending = pendingOpen, index.documents.contains(pending) {
            pendingOpen = nil
            open(pending)
            return
        }
        if index.notes.isEmpty { message = "No notes were found in this folder. Notes in iCloud may still be downloading." }
        if reopenLast, let last = UserDefaults.standard.string(forKey: lastNoteKey), index.documents.contains(last) {
            open(last)
        }
    }

    /// Reads the folder again and shows the open note again (it may have changed).
    func refresh() {
        guard let url = rootBox.url else { return }
        let current = selectedPath
        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let index = VaultIndex(root: url)
            index.scan()
            await self?.finishRefresh(index, current: current)
        }
    }

    private func finishRefresh(_ index: VaultIndex, current: String?) {
        self.index = index
        tree = index.tree
        isLoading = false
        publishToWidgets(index)
        if let current = current, index.documents.contains(current) { open(current, fragment: nil, keepScroll: true) }
    }

    // MARK: Widgets

    /// Writes what the home screen widgets need (they cannot open the vault) and refreshes them.
    private func publishToWidgets(_ index: VaultIndex) {
        let name = vaultName ?? "Vault"
        Task.detached(priority: .utility) {
            guard let store = SnapshotStore.appGroup() else { return }
            let snapshot = WidgetSnapshot.build(from: index, vaultName: name)
            if (try? store.write(snapshot)) != nil { WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    /// A `vaultviewer://open?path=...` link, from a widget.
    func handle(url: URL) {
        guard let path = DeepLink.notePath(from: url) else { return }
        if let index = index {
            if index.documents.contains(path) { open(path) }
        } else {
            pendingOpen = path   // The vault is still loading: open it when it is ready.
        }
    }

    // MARK: Opening notes

    /// True for notes and PDFs, the things a click can open.
    func isOpenable(_ path: String) -> Bool { index?.documents.contains(path) ?? false }

    private func isPDF(_ path: String) -> Bool { (path as NSString).pathExtension.lowercased() == "pdf" }

    func search(_ query: String) -> [String] { index?.search(query) ?? [] }

    func open(_ path: String, fragment: String? = nil, keepScroll: Bool = false) {
        guard let index = index, let root = rootBox.url, index.documents.contains(path) else { return }
        if isPDF(path) { return openPDF(path, fragment: fragment, root: root) }
        pdf = nil
        selectedPath = path
        scrollTarget = fragment
        UserDefaults.standard.set(path, forKey: lastNoteKey)
        openToken += 1
        let token = openToken
        isLoading = true
        message = nil

        Task.detached(priority: .userInitiated) { [weak self] in
            // Coordinated reads make iCloud download a note that is not on the device yet.
            let loadNote: (String) -> String? = { relative in
                VaultFiles.readText(root.appendingPathComponent(relative))
            }
            guard let text = loadNote(path) else {
                await self?.failed(token, "“\((path as NSString).lastPathComponent)” could not be read. If it is in iCloud, check your connection and try again.")
                return
            }
            let rendered = NoteRenderer.render(markdown: text, notePath: path, resolver: index, loadNote: loadNote)
            await self?.finished(token, rendered, title: ((path as NSString).lastPathComponent as NSString).deletingPathExtension)
        }
    }

    private func openPDF(_ path: String, fragment: String?, root: URL) {
        selectedPath = path
        scrollTarget = nil
        UserDefaults.standard.set(path, forKey: lastNoteKey)
        openToken += 1
        let token = openToken
        isLoading = true
        message = nil
        let page = fragment.flatMap(PDFLink.page(fromFragment:)) ?? 1

        Task.detached(priority: .userInitiated) { [weak self] in
            switch PDFLoader.load(root.appendingPathComponent(path)) {
            case let .success(document):
                await self?.finishedPDF(token, PDFItem(path: path, document: document, page: page))
            case let .failure(failure):
                await self?.failed(token, PDFLoader.message(for: failure, name: (path as NSString).lastPathComponent))
            }
        }
    }

    private func finishedPDF(_ token: Int, _ item: PDFItem) {
        guard token == openToken else { return }
        pdf = item
        note = nil
        noteTitle = item.name
        isLoading = false
    }

    private func finished(_ token: Int, _ rendered: RenderedNote, title: String) {
        guard token == openToken else { return }   // The user already opened another note.
        note = rendered
        pdf = nil
        noteTitle = title
        isLoading = false
    }

    private func failed(_ token: Int, _ text: String) {
        guard token == openToken else { return }
        note = nil
        pdf = nil
        isLoading = false
        message = text
    }
}
