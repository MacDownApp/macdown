import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

/// Reads the page number out of a link fragment: `page=3`, `page=3&zoom=100`, or just `3`.
public enum PDFLink {
    public static func page(fromFragment fragment: String) -> Int? {
        let decoded = fragment.removingPercentEncoding ?? fragment
        for part in decoded.split(whereSeparator: { $0 == "&" || $0 == "," }) {
            let piece = part.trimmingCharacters(in: .whitespaces).lowercased()
            if piece.hasPrefix("page="), let n = Int(piece.dropFirst(5)), n >= 1 { return n }
        }
        if let n = Int(decoded.trimmingCharacters(in: .whitespaces)), n >= 1 { return n }
        return nil
    }
}

#if canImport(PDFKit)
public enum PDFLoader {
    /// Largest PDF the viewer will load, so a huge file cannot use all memory.
    public static let maxBytes = 300 * 1024 * 1024

    public enum Failure: Error, Equatable { case notReadable, tooLarge, notAPDF, locked }

    /// Reads a PDF from the vault (through the file coordinator, so iCloud downloads it) and opens it.
    /// Blocks: call it off the main thread.
    public static func load(_ file: URL) -> Result<PDFDocument, Failure> {
        guard let data = VaultFiles.readData(file) else { return .failure(.notReadable) }
        return open(data)
    }

    static func open(_ data: Data) -> Result<PDFDocument, Failure> {
        guard data.count <= maxBytes else { return .failure(.tooLarge) }
        guard let document = PDFDocument(data: data), document.pageCount > 0 else { return .failure(.notAPDF) }
        if document.isLocked { return .failure(.locked) }
        return .success(document)
    }

    public static func message(for failure: Failure, name: String) -> String {
        switch failure {
        case .notReadable: return "“\(name)” could not be read. If it is in iCloud, check your connection and try again."
        case .tooLarge: return "“\(name)” is too large to open here."
        case .notAPDF: return "“\(name)” is not a readable PDF."
        case .locked: return "“\(name)” is password protected, which this viewer does not support."
        }
    }
}
#endif
