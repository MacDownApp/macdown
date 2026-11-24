import SwiftUI
import WebKit
import ViewerCore

/// The page of one note. Links are handled here: notes open in the app, web links open in
/// Safari, and nothing else may navigate the page.
struct NoteWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL
    let currentPath: String
    let zoom: Double
    let background: UIColor
    let store: VaultStore

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let box = store.rootBox
        configuration.setURLSchemeHandler(
            ViewerSchemeHandler(appRoot: Bundle.main.resourceURL ?? URL(fileURLWithPath: "/"), vaultRoot: { box.url }),
            forURLScheme: ViewerSchemeHandler.scheme)
        configuration.websiteDataStore = .nonPersistent()   // Nothing is stored; diagram caches live while the app runs.
        let web = WKWebView(frame: .zero, configuration: configuration)
        web.navigationDelegate = context.coordinator
        web.isOpaque = false
        web.allowsLinkPreview = false
        web.scrollView.contentInsetAdjustmentBehavior = .automatic
        context.coordinator.web = web
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.currentPath = currentPath
        web.backgroundColor = background
        web.scrollView.backgroundColor = background
        if abs(web.pageZoom - zoom) > 0.001 { web.pageZoom = zoom }
        if coordinator.loadedHTML != html {
            coordinator.loadedHTML = html
            coordinator.baseURL = baseURL
            web.loadHTMLString(html, baseURL: baseURL)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let store: VaultStore
        weak var web: WKWebView?
        var loadedHTML = ""
        var baseURL: URL?
        var currentPath = ""

        init(store: VaultStore) { self.store = store }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard action.navigationType == .linkActivated, let url = action.request.url else { return decisionHandler(.allow) }

            // A link to a place on this page.
            if let base = baseURL, url.fragment != nil, strip(url) == strip(base) { return decisionHandler(.allow) }

            switch url.scheme {
            case ViewerSchemeHandler.scheme:
                let path = String(url.path.dropFirst())
                let fragment = url.fragment?.removingPercentEncoding
                if url.host == "note" || (url.host == "vault" && isOpenable(path)) {
                    if path == currentPath, !isPDF(path), let fragment = fragment {
                        scroll(to: fragment)
                    } else {
                        Task { @MainActor in self.store.open(path, fragment: fragment) }
                    }
                }
                decisionHandler(.cancel)
            case "http", "https", "mailto", "tel":
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            default:
                decisionHandler(.cancel)
            }
        }

        private func isPDF(_ path: String) -> Bool { (path as NSString).pathExtension.lowercased() == "pdf" }

        /// Notes and PDFs open in the app; other files do nothing.
        private func isOpenable(_ path: String) -> Bool {
            let ext = (path as NSString).pathExtension.lowercased()
            return ext == "md" || ext == "markdown" || ext == "pdf"
        }

        private func strip(_ url: URL) -> String {
            var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
            parts?.fragment = nil
            return parts?.string ?? url.absoluteString
        }

        private func scroll(to heading: String) {
            let literal = (try? String(data: JSONEncoder().encode(heading), encoding: .utf8)) ?? "\"\""
            web?.evaluateJavaScript("window.scrollToHeading(\(literal));", completionHandler: nil)
        }
    }
}
