import Foundation
import WebKit
import UniformTypeIdentifiers

/// Serves `macdown-file://` requests from the file system.
///
/// Safety rules:
/// - Only requests that start from our own pages are served. A request that
///   carries a foreign `Origin` or `Referer` (for example from a remote iframe
///   in the document) gets 403.
/// - No CORS headers are sent, so other origins cannot read the answers.
/// - Only regular files are served, never folders.
///
/// Threading: file reads run on a background queue; every call into WebKit happens on the
/// main thread, with no lock held.
final class PreviewSchemeHandler: NSObject, WKURLSchemeHandler {
    /// Requests WebKit has started and not stopped or finished. Only touched on the main
    /// thread (WebKit calls `start` and `stop` there, and replies are sent from there), so
    /// there is no lock. A lock here once froze the whole app: a background thread held it
    /// while WebKit waited for the main thread, which was waiting for the same lock.
    private var active = Set<ObjectIdentifier>()
    private let queue = DispatchQueue(label: "app.macdown.preview-files", qos: .userInitiated, attributes: .concurrent)

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        let id = ObjectIdentifier(task)
        active.insert(id)
        let request = task.request

        guard let url = request.url, url.scheme == PreviewURL.scheme else {
            return finish(task, id, status: 400, body: Data())
        }
        for header in ["Origin", "Referer"] {
            if let value = request.value(forHTTPHeaderField: header), !value.isEmpty, value != "null",
               !value.hasPrefix(PreviewURL.scheme + ":") {
                return finish(task, id, status: 403, body: Data())
            }
        }
        let path = (url.path as NSString).standardizingPath
        let rangeHeader = request.value(forHTTPHeaderField: "Range")

        // Read the file off the main thread; answer on the main thread.
        queue.async { [weak self] in
            var isDirectory: ObjCBool = false
            guard !path.isEmpty, FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  !isDirectory.boolValue,
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            else {
                DispatchQueue.main.async { self?.finish(task, id, status: 404, body: Data()) }
                return
            }
            var headers = ["Content-Type": PreviewSchemeHandler.mimeType(forPath: path),
                           "Cache-Control": "no-store"]
            var status = 200
            var body = data
            if let rangeHeader = rangeHeader, let range = PreviewSchemeHandler.parseRange(rangeHeader, length: data.count) {
                headers["Content-Range"] = "bytes \(range.lowerBound)-\(range.upperBound - 1)/\(data.count)"
                status = 206
                body = data.subdata(in: range)
            }
            DispatchQueue.main.async { self?.finish(task, id, url: url, status: status, headers: headers, body: body) }
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        active.remove(ObjectIdentifier(task))
    }

    // MARK: Answering (main thread)

    private func finish(_ task: WKURLSchemeTask, _ id: ObjectIdentifier, url: URL? = nil, status: Int,
                        headers: [String: String] = [:], body: Data) {
        // Calling a stopped task raises an exception, so only answer tasks that are still active.
        guard active.remove(id) != nil else { return }
        var fields = headers
        fields["Content-Length"] = String(body.count)
        let responseURL = url ?? task.request.url ?? URL(string: "\(PreviewURL.scheme):///")!
        guard let response = HTTPURLResponse(url: responseURL, statusCode: status, httpVersion: "HTTP/1.1", headerFields: fields) else {
            return task.didFailWithError(URLError(.badServerResponse))
        }
        task.didReceive(response)
        task.didReceive(body)
        task.didFinish()
    }

    // MARK: Helpers

    static func mimeType(forPath path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "js", "mjs": return "text/javascript"
        case "css": return "text/css"
        case "html", "htm": return "text/html"
        case "json": return "application/json"
        case "svg": return "image/svg+xml"
        case "md", "markdown", "txt": return "text/plain"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        case "otf": return "font/otf"
        case "eot": return "application/vnd.ms-fontobject"
        default: return UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
        }
    }

    /// Parses `bytes=a-b`, `bytes=a-` and `bytes=-n`. Returns a valid range of the data, or nil.
    static func parseRange(_ header: String, length: Int) -> Range<Int>? {
        guard header.hasPrefix("bytes="), length > 0 else { return nil }
        let spec = header.dropFirst("bytes=".count)
        guard !spec.contains(",") else { return nil }
        let parts = spec.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 else { return nil }
        if parts[0].isEmpty {                         // "-n": the last n bytes.
            guard let n = Int(parts[1]), n > 0 else { return nil }
            return max(0, length - n)..<length
        }
        guard let start = Int(parts[0]), start >= 0, start < length else { return nil }
        if parts[1].isEmpty { return start..<length }
        guard let end = Int(parts[1]), end >= start else { return nil }
        return start..<min(end + 1, length)
    }
}
