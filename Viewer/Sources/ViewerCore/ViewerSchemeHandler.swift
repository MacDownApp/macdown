import Foundation
import WebKit
import UniformTypeIdentifiers

/// Serves the `md://` URLs of the viewer page:
/// - `md://app/<path>`: files inside the app (KaTeX, Mermaid, Prism).
/// - `md://vault/<path>`: files inside the vault folder (images, attachments).
///
/// Safety: a path may never leave its root (`..` is refused), only regular files are served,
/// and no CORS header is sent. Vault files are read through `NSFileCoordinator`, which also
/// makes iCloud download a file that is not on the device yet.
///
/// Threading: reads run on a background queue, and every call into WebKit happens on the main
/// thread with no lock held (a lock here once froze the macOS app).
public final class ViewerSchemeHandler: NSObject, WKURLSchemeHandler {
    public static let scheme = "md"

    private let appRoot: URL
    private let vaultRoot: () -> URL?
    private var active = Set<ObjectIdentifier>()   // Main thread only.
    private let queue = DispatchQueue(label: "viewer.files", qos: .userInitiated, attributes: .concurrent)

    /// - Parameters:
    ///   - appRoot: folder that `md://app/` maps to (the app bundle's resources).
    ///   - vaultRoot: the current vault folder (asked each time, so the vault can change).
    public init(appRoot: URL, vaultRoot: @escaping () -> URL?) {
        self.appRoot = appRoot
        self.vaultRoot = vaultRoot
    }

    public func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        let id = ObjectIdentifier(task)
        active.insert(id)
        guard let url = task.request.url, url.scheme == ViewerSchemeHandler.scheme,
              let file = VaultFiles.fileURL(for: url, appRoot: appRoot, vaultRoot: vaultRoot()) else {
            return finish(task, id, status: 404, body: Data(), contentType: "text/plain")
        }
        let coordinated = url.host == "vault"
        queue.async { [weak self] in
            let data = VaultFiles.read(file, coordinated: coordinated)
            DispatchQueue.main.async {
                if let data = data {
                    self?.finish(task, id, status: 200, body: data, contentType: VaultFiles.mimeType(forPath: file.path))
                } else {
                    self?.finish(task, id, status: 404, body: Data(), contentType: "text/plain")
                }
            }
        }
    }

    public func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        active.remove(ObjectIdentifier(task))
    }

    private func finish(_ task: WKURLSchemeTask, _ id: ObjectIdentifier, status: Int, body: Data, contentType: String) {
        guard active.remove(id) != nil else { return }   // Answering a stopped task would raise an exception.
        let fields = ["Content-Type": contentType, "Content-Length": String(body.count), "Cache-Control": "no-store"]
        guard let url = task.request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: fields) else {
            return task.didFailWithError(URLError(.badServerResponse))
        }
        task.didReceive(response)
        task.didReceive(body)
        task.didFinish()
    }
}

/// File access rules for the viewer. A plain type (not part of the WebKit handler class), so it can be
/// called from any thread.
public enum VaultFiles {
    /// Maps a `md://app/...` or `md://vault/...` URL to a file, or nil if the host is unknown, there is
    /// no vault, or the path would leave its root.
    static func fileURL(for url: URL, appRoot: URL, vaultRoot: URL?) -> URL? {
        let root: URL
        switch url.host {
        case "app": root = appRoot
        case "vault": guard let vault = vaultRoot else { return nil }; root = vault
        default: return nil
        }
        let parts = url.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !parts.contains(".."), !parts.contains(".") else { return nil }
        var file = root
        for part in parts { file.appendPathComponent(part) }
        return file
    }

    /// Reads a file through the file coordinator (so iCloud downloads it if needed). Blocks.
    public static func readData(_ file: URL) -> Data? { read(file, coordinated: true) }

    /// Reads a text file through the file coordinator (so iCloud downloads it if needed).
    /// Blocks: call it off the main thread.
    public static func readText(_ file: URL) -> String? {
        guard let data = read(file, coordinated: true) else { return nil }
        return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }

    /// How long to wait for an iCloud download before giving up.
    nonisolated(unsafe) static var downloadTimeout: TimeInterval = 30

    static func read(_ file: URL, coordinated: Bool) -> Data? {
        var isDirectory: ObjCBool = false
        if !coordinated {
            guard FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory), !isDirectory.boolValue else { return nil }
            return try? Data(contentsOf: file, options: .mappedIfSafe)
        }
        // iCloud: a file that is not on the device is a hidden ".name.icloud" placeholder. Ask for the
        // download and wait for the real file to appear (up to `downloadTimeout` seconds).
        let placeholder = file.deletingLastPathComponent().appendingPathComponent("." + file.lastPathComponent + ".icloud")
        if !FileManager.default.fileExists(atPath: file.path), FileManager.default.fileExists(atPath: placeholder.path) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: file)
            let deadline = Date().addingTimeInterval(downloadTimeout)
            while !FileManager.default.fileExists(atPath: file.path), Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        }
        // Coordinated, so a file that is being synced is read in a consistent state.
        var data: Data?
        var coordinationError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: file, options: [], error: &coordinationError) { readable in
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: readable.path, isDirectory: &isDir), !isDir.boolValue else { return }
            data = try? Data(contentsOf: readable)
        }
        return data
    }

    static func mimeType(forPath path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "js", "mjs": return "text/javascript"
        case "css": return "text/css"
        case "svg": return "image/svg+xml"
        case "json": return "application/json"
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        case "md", "markdown", "txt": return "text/plain; charset=utf-8"
        default: return UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
        }
    }
}
