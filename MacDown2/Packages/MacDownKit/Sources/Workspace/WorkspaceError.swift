import FileCore

/// Errors surfaced by the workspace shell when routing commands to `FileCore`.
public enum WorkspaceError: Error {
    case openFailed(underlying: FileStoreError)
    case saveFailed(underlying: FileStoreError)
    case noActiveDocument
}
