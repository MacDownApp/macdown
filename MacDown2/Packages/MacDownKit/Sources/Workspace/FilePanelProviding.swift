import FileCore
import Foundation

/// Platform file panels, abstracted so `WorkspaceModel` is testable without
/// AppKit or a real window.
public protocol FilePanelProviding: Sendable {
    /// Prompt for one existing file. Returns `nil` if the user cancels.
    func chooseFile() async -> URL?
    /// Prompt for one existing directory. Returns `nil` if the user cancels.
    func chooseFolder() async -> URL?
    /// Prompt for a save destination for an untitled document. Returns `nil` if
    /// the user cancels.
    func chooseSaveLocation(defaultName: String, format: FileFormat) async -> URL?
}

// MARK: - Test fakes

/// A scripted file panel provider for tests.
///
/// `FakeFilePanelProvider` uses `@unchecked Sendable` because it stores mutable
/// scripted URL state that is only ever mutated from the `@MainActor` test
/// harness. This keeps the test fake lightweight while satisfying the
/// `FilePanelProviding: Sendable` protocol requirement.
public final class FakeFilePanelProvider: FilePanelProviding, @unchecked Sendable {
    public var nextFileURL: URL?
    public var nextFolderURL: URL?
    public var nextSaveURL: URL?

    public init() {}

    public func chooseFile() async -> URL? {
        defer { nextFileURL = nil }
        return nextFileURL
    }

    public func chooseFolder() async -> URL? {
        defer { nextFolderURL = nil }
        return nextFolderURL
    }

    public func chooseSaveLocation(defaultName _: String, format _: FileFormat) async -> URL? {
        defer { nextSaveURL = nil }
        return nextSaveURL
    }
}

/// A file panel provider that never opens a panel and always returns `nil`.
public struct NoOpFilePanelProvider: FilePanelProviding {
    public init() {}
    public func chooseFile() async -> URL? {
        nil
    }

    public func chooseFolder() async -> URL? {
        nil
    }

    public func chooseSaveLocation(defaultName _: String, format _: FileFormat) async -> URL? {
        nil
    }
}
