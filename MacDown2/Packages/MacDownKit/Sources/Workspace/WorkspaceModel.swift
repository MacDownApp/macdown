import FileCore
import Foundation
import Observation

/// Sidebar sections displayed in the workspace shell.
public enum SidebarSection: String, Sendable, CaseIterable {
    case folder
    case outline
}

/// The observable model behind the MacDown 2 workspace shell.
///
/// Responsibilities:
/// - Track the active document and opened folder.
/// - Route File menu intents (`newDocument`, `openFile`, `save`, `close`, …).
/// - Expose command enablement state for SwiftUI `Commands`.
/// - Persist window UI state (sidebar visibility, section expansion).
///
/// `WorkspaceModel` is deliberately a single-document shell. Tabs and session
/// restore are EPIC-03; do not add tab state here.
@MainActor
@Observable
public final class WorkspaceModel {
    /// The document currently shown in the content area.
    public internal(set) var activeDocument: FileDocument?

    /// The folder opened via ⌘⇧O, if any. The actual folder tree UI is E09.
    public private(set) var folderURL: URL?

    /// The most recent error surfaced to the user. Views may present this.
    public private(set) var lastError: WorkspaceError?

    /// `true` while a dirty-close alert should be shown by the view.
    /// The view may set this back to `false` when dismissing the alert; callers
    /// should normally use `resolveClose(_:)` to drive the actual close decision.
    public var pendingClose: Bool

    /// Whether the sidebar column is visible. Persisted via `stateStore`.
    public var sidebarVisible: Bool {
        didSet {
            stateStore.sidebarVisible = sidebarVisible
        }
    }

    public var hasActiveDocument: Bool {
        activeDocument != nil
    }

    /// `true` if the active document can be saved right now.
    public var canSave: Bool {
        guard let document = activeDocument else { return false }
        if document.fileURL == nil {
            return !document.text.isEmpty
        }
        return document.state == .dirty || document.state == .conflict
    }

    /// `true` if there is an active document that can be closed.
    public var canClose: Bool {
        activeDocument != nil
    }

    private var stateStore: WorkspaceStateStoring
    private let panel: any FilePanelProviding
    /// Action to run after a dirty-close prompt resolves with Save/Discard.
    /// Used so intents like `openFile()` and `newDocument()` can continue once
    /// the dirty document is closed.
    private var pendingAction: (@MainActor () async -> Void)?

    public init(
        stateStore: WorkspaceStateStoring = WorkspaceStateStore(),
        panel: (any FilePanelProviding)? = nil
    ) {
        self.stateStore = stateStore
        self.panel = panel ?? NoOpFilePanelProvider()
        activeDocument = nil
        folderURL = nil
        lastError = nil
        pendingClose = false
        pendingAction = nil
        sidebarVisible = stateStore.sidebarVisible
    }

    // MARK: - State store helpers

    public func isSectionExpanded(_ section: SidebarSection) -> Bool {
        stateStore.sidebarSectionExpanded[section.rawValue] ?? true
    }

    public func setSectionExpanded(_ section: SidebarSection, _ expanded: Bool) {
        stateStore.sidebarSectionExpanded[section.rawValue] = expanded
    }

    // MARK: - Intents

    /// Creates a new untitled document.
    ///
    /// If the current document has unsaved changes, the dirty-close prompt is
    /// shown first and the new document is created after the user saves or
    /// discards.
    public func newDocument() async {
        guard await canProceedDespiteDirtyDocument(continuation: { [weak self] in
            await self?.newDocument()
        }) else { return }

        activeDocument = FileDocument()
        lastError = nil
    }

    /// Opens an existing file chosen by the user.
    ///
    /// If the current document has unsaved changes, the dirty-close prompt is
    /// shown first and the file panel is presented after the user saves or
    /// discards.
    public func openFile() async {
        guard await canProceedDespiteDirtyDocument(continuation: { [weak self] in
            await self?.openFile()
        }) else { return }

        guard let url = await panel.chooseFile() else { return }
        await loadDocument(from: url)
    }

    /// Opens a folder chosen by the user.
    public func openFolder() async {
        guard let url = await panel.chooseFolder() else { return }
        folderURL = url
    }

    /// Saves the active document. Untitled documents prompt for a location.
    public func save() async {
        guard let document = activeDocument else {
            lastError = .noActiveDocument
            return
        }

        if document.fileURL == nil {
            await saveAs()
            return
        }

        do {
            activeDocument = try document.save()
            lastError = nil
        } catch {
            activeDocument = document
            lastError = .saveFailed(underlying: cast(error))
        }
    }

    /// Saves the active document to a user-chosen location.
    public func saveAs() async {
        guard let document = activeDocument else {
            lastError = .noActiveDocument
            return
        }

        let defaultName = document.fileURL?.lastPathComponent
            ?? "Untitled.\(document.format.extensions.first ?? "md")"
        guard let url = await panel.chooseSaveLocation(
            defaultName: defaultName,
            format: document.format
        ) else { return }

        do {
            activeDocument = try document.saveAs(url)
            await activeDocument?.clearRecovery()
            lastError = nil
        } catch {
            activeDocument = document
            lastError = .saveFailed(underlying: cast(error))
        }
    }

    /// Begins closing the active document.
    ///
    /// Clean documents close synchronously. Dirty documents set `pendingClose`
    /// and wait for the view to call `resolveClose(_:)`.
    public func requestCloseDocument() {
        guard let document = activeDocument else { return }
        let (updated, resolution) = document.requestClose()
        if let resolution {
            activeDocument = resolution == .discard ? nil : updated
        } else {
            pendingClose = true
        }
    }

    /// Resolves a dirty-close prompt.
    public func resolveClose(_ resolution: CloseResolution) async {
        pendingClose = false
        let action = pendingAction
        pendingAction = nil
        await applyCloseResolution(resolution)
        if resolution != .cancel, let action {
            await action()
        }
    }

    // MARK: - Internal helpers

    /// Returns `false` if the current dirty document blocks the action.
    ///
    /// For a clean document the close resolution is applied immediately and the
    /// caller may proceed. For a dirty document the alert is presented and the
    /// supplied `continuation` is run after the user saves or discards.
    private func canProceedDespiteDirtyDocument(
        continuation: @escaping @MainActor () async -> Void
    ) async -> Bool {
        guard let document = activeDocument else { return true }
        let (updated, resolution) = document.requestClose()
        if let resolution {
            await applyCloseResolution(resolution)
            return activeDocument == nil
        } else {
            activeDocument = updated
            pendingClose = true
            // Single-slot continuation. This is safe because the dirty-close
            // alert is modal: no other intent (New/Open) can fire while it is
            // shown, so `pendingAction` is never overwritten mid-prompt. It is
            // always cleared in `resolveClose(_:)`, including on cancel.
            pendingAction = continuation
            return false
        }
    }

    private func applyCloseResolution(_ resolution: CloseResolution) async {
        guard let document = activeDocument else { return }

        switch resolution {
        case .save:
            await save()
            // If save failed or was cancelled, abort the close.
            if activeDocument?.state == .dirty || activeDocument?.state == .conflict {
                return
            }
            activeDocument = nil
        case .discard:
            activeDocument = nil
        case .cancel:
            // Return to a normal dirty state so editing can continue.
            activeDocument = document.resolveClose(.cancel)
        }
    }

    private func loadDocument(from url: URL) async {
        let document = FileDocument(fileURL: url)
        do {
            activeDocument = try document.load()
            lastError = nil
        } catch {
            activeDocument = nil
            lastError = .openFailed(underlying: cast(error))
        }
    }

    private func cast(_ error: Error) -> FileStoreError {
        error as? FileStoreError ?? .readFailed(underlying: error)
    }
}
