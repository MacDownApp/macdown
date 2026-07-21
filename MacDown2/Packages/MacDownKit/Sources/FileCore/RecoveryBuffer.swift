import Foundation

/// Persists a recovery copy of untitled document content so that a crash or
/// force-quit does not lose unsaved work.
///
/// Recovery files are stored in `~/Library/Application Support/MacDown 2/Recovery`
/// and keyed by a stable document identifier supplied by `FileDocument`.
public actor RecoveryBuffer {
    public static let shared = RecoveryBuffer()

    private let recoveryDirectory: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        recoveryDirectory = appSupport.appendingPathComponent("MacDown 2/Recovery", isDirectory: true)
    }

    /// Writes a recovery copy for the given document identifier.
    public func save(content: String, for documentID: String) throws {
        let url = fileURL(for: documentID)
        try FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Reads the recovery copy for the given document identifier, if any.
    public func load(for documentID: String) throws -> String? {
        let url = fileURL(for: documentID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Removes the recovery copy for the given document identifier.
    public func remove(for documentID: String) {
        let url = fileURL(for: documentID)
        try? FileManager.default.removeItem(at: url)
    }

    /// Removes all recovery buffers. Useful after a successful session restore.
    public func removeAll() {
        try? FileManager.default.removeItem(at: recoveryDirectory)
    }

    private func fileURL(for documentID: String) -> URL {
        // Only UUID-based IDs reach this path today (recovery is for untitled
        // documents), but sanitize defensively so any future identifier is a
        // safe single path component: keep alphanumerics plus `-_.`, and map
        // everything else (`/`, `:`, `%`, whitespace, …) to `_`.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let sanitized = String(documentID.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return recoveryDirectory.appendingPathComponent("\(sanitized).recovery.md")
    }
}
