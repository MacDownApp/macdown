import Foundation
import UniformTypeIdentifiers

/// The state of a document's dirty flag and close-dirty prompt flow.
///
/// The machine is intentionally simple and synchronous at its core; IO is
/// delegated to `FileStore` and `RecoveryBuffer`.
public enum FileDocumentState: Sendable, Equatable {
    /// No unsaved changes.
    case clean
    /// Has unsaved changes.
    case dirty
    /// Dirty and the user is being asked how to resolve the close.
    case promptingClose
    /// An external change was detected; the user must choose how to reconcile.
    case conflict
}

/// The user's choice when closing a dirty document.
public enum CloseResolution: Sendable, Equatable {
    case save
    case discard
    case cancel
}

/// The user's choice when an external file change conflicts with in-memory edits.
public enum ConflictResolution: Sendable, Equatable {
    case keepMine
    case useExternal
    case cancel
}

/// Represents an open document and its lifecycle state.
///
/// `FileDocument` is a value type: mutating the state machine returns a new
/// instance, keeping the core pure and synchronous. IO is performed at the
/// edges by `FileStore` and `RecoveryBuffer`, which are injected so tests can
/// substitute them.
public struct FileDocument: Sendable {
    /// A stable identifier. For saved files this is the file URL's absolute
    /// string; for untitled documents it is a generated UUID.
    public let id: String

    /// The URL of the file on disk, or `nil` for untitled documents.
    public var fileURL: URL?

    /// The current text content of the document.
    public var text: String

    /// The format associated with this document.
    public let format: FileFormat

    /// The current lifecycle state.
    public var state: FileDocumentState

    /// The last known modification date of the file on disk, used to detect
    /// external changes.
    public var lastKnownModificationDate: Date?

    /// The store used for disk IO. Injected to allow test doubles.
    public let fileStore: FileStore

    /// Creates a new document, optionally backed by an existing file.
    public init(
        fileURL: URL? = nil,
        text: String = "",
        format: FileFormat? = nil,
        fileStore: FileStore = FileStore()
    ) {
        self.fileURL = fileURL
        self.text = text
        self.fileStore = fileStore
        state = .clean

        if let fileURL {
            id = fileURL.absoluteString
            self.format = format ?? FileFormat.format(for: fileURL, in: FileFormatRegistry())
                ?? FileFormatRegistry.defaultFormats.first { $0.id == "plaintext" }
                ?? FileFormat(id: "plaintext", name: "Plain Text", utType: .plainText, extensions: ["txt"])
        } else {
            id = UUID().uuidString
            self.format = format ?? FileFormatRegistry.defaultFormats.first { $0.id == "markdown" }
                ?? FileFormat(
                    id: "markdown",
                    name: "Markdown",
                    utType: UTType(filenameExtension: "md") ?? .plainText,
                    extensions: ["md"],
                    highlightLanguageID: "markdown",
                    previewCapability: .rendered
                )
        }
    }

    // MARK: - State transitions

    /// Marks the document as clean (used after a successful save or discard).
    public func markClean() -> FileDocument {
        var copy = self
        copy.state = .clean
        return copy
    }

    /// Begins the close flow for a dirty document, transitioning to prompting.
    public func requestClose() -> (document: FileDocument, resolution: CloseResolution?) {
        var copy = self
        switch state {
        case .clean:
            return (copy, .discard)
        case .dirty, .conflict:
            copy.state = .promptingClose
            return (copy, nil)
        case .promptingClose:
            return (copy, nil)
        }
    }

    /// Resolves the close prompt.
    public func resolveClose(_ resolution: CloseResolution) -> FileDocument {
        var copy = self
        switch resolution {
        case .save, .discard:
            copy.state = .clean
        case .cancel:
            // Only a document that was actually prompting to close returns to
            // `.dirty`. Guard against dirtying an already-clean document if
            // `resolveClose(.cancel)` is ever called out of the prompt flow.
            copy.state = (state == .promptingClose) ? .dirty : state
        }
        return copy
    }

    // MARK: - File IO

    /// Loads content from the document's `fileURL` into a new instance with `text` set.
    public func load() throws(FileStoreError) -> FileDocument {
        guard let fileURL else {
            throw .invalidURL
        }
        let (content, _) = try fileStore.read(from: fileURL)
        var copy = self
        copy.text = content
        copy.lastKnownModificationDate = modificationDate(of: fileURL)
        copy.state = .clean
        return copy
    }

    /// Saves the current `text` to the document's `fileURL`.
    public func save() throws(FileStoreError) -> FileDocument {
        guard let fileURL else {
            // Untitled documents are not saved to disk; their recovery buffer
            // is maintained separately by `autosave()`.
            throw .invalidURL
        }

        try fileStore.write(text, to: fileURL)
        var copy = self
        copy.lastKnownModificationDate = modificationDate(of: fileURL)
        copy.state = .clean
        return copy
    }

    /// Saves the current text to a new URL and updates the document identity.
    public func saveAs(_ url: URL) throws(FileStoreError) -> FileDocument {
        try fileStore.write(text, to: url)
        var copy = self
        copy.fileURL = url
        copy.lastKnownModificationDate = modificationDate(of: url)
        copy.state = .clean
        return copy
    }

    // MARK: - Autosave / recovery

    /// Writes a recovery copy if this is an untitled document.
    public func autosave() async {
        guard fileURL == nil else { return }
        try? await RecoveryBuffer.shared.save(content: text, for: id)
    }

    /// Loads the recovery copy for an untitled document, if present.
    public func loadRecovery() async -> String? {
        guard fileURL == nil else { return nil }
        return try? await RecoveryBuffer.shared.load(for: id)
    }

    /// Clears the recovery copy (call after a successful save-as or explicit discard).
    public func clearRecovery() async {
        await RecoveryBuffer.shared.remove(for: id)
    }

    // MARK: - External change detection

    /// Checks whether the file on disk has been modified since it was last read or saved.
    public func detectExternalChange() -> Bool {
        guard let fileURL, let lastKnown = lastKnownModificationDate else { return false }
        guard let current = modificationDate(of: fileURL) else { return false }
        return current > lastKnown
    }

    /// Resolves an external-change conflict.
    public func resolveConflict(_ resolution: ConflictResolution) throws(FileStoreError) -> FileDocument {
        switch resolution {
        case .keepMine:
            var copy = self
            copy.state = .dirty
            return copy
        case .useExternal:
            return try load()
        case .cancel:
            return self
        }
    }

    // MARK: - Helpers

    private func modificationDate(of url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }
}

// MARK: - Text mutation

public extension FileDocument {
    /// Returns a new document with `text` updated and the dirty flag set.
    func updatingText(_ newText: String) -> FileDocument {
        guard newText != text else { return self }
        var copy = self
        copy.text = newText
        switch copy.state {
        case .clean:
            copy.state = .dirty
        case .dirty, .conflict:
            break
        case .promptingClose:
            // If the user edits while being prompted, return to dirty.
            copy.state = .dirty
        }
        return copy
    }
}
