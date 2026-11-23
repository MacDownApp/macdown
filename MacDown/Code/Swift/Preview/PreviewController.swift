import AppKit
import WebKit

@objc(MPPreviewControllerDelegate)
protocol PreviewControllerDelegate: AnyObject {
    /// A page finished loading (or failed to).
    func previewDidFinishLoading(_ preview: PreviewController)
    /// MathJax finished typesetting.
    func previewMathJaxDidFinish(_ preview: PreviewController)
    /// The user clicked a link. `url` is a `file` URL for local targets. Return true to let the
    /// preview go there (for example to a heading on the same page), false if the app handled it.
    @objc(preview:shouldNavigateToURL:)
    func preview(_ preview: PreviewController, shouldNavigateTo url: URL) -> Bool
    /// The page was scrolled by the user.
    func previewDidScroll(_ preview: PreviewController)
}

/// A web view that never accepts dropped files: dropping on it must not navigate away.
@objc(MPPreviewWebView)
final class PreviewWebView: WKWebView {
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { [] }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { [] }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { false }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool { false }
}

/// Owns the preview web view: loading, links, scrolling, zoom, printing.
///
/// The web view is created here, not in the nib, because a URL scheme handler
/// has to be set before a `WKWebView` exists.
@objc(MPPreviewController)
final class PreviewController: NSObject {
    @objc let webView: PreviewWebView
    @objc weak var delegate: PreviewControllerDelegate?

    @objc private(set) var isLoading = false
    /// Top of each heading and lone image, in page coordinates.
    @objc private(set) var headerLocations: [NSNumber] = []
    @objc private(set) var contentHeight: CGFloat = 0
    @objc private(set) var visibleHeight: CGFloat = 0
    @objc private(set) var scrollY: CGFloat = 0

    private var lastLoad: (html: String, base: URL?)?
    private var crashReloads = 0
    private static let messageName = "macdown"

    /// Creates the web view and puts it where `placeholder` is.
    @objc(initWithPlaceholder:delegate:)
    init(replacing placeholder: NSView, delegate: PreviewControllerDelegate?) {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(PreviewSchemeHandler(), forURLScheme: PreviewURL.scheme)
        configuration.websiteDataStore = .nonPersistent()   // No cache: edits to images must show.
        webView = PreviewWebView(frame: placeholder.frame, configuration: configuration)
        self.delegate = delegate
        super.init()

        configuration.userContentController.add(WeakScriptMessageHandler(self), name: PreviewController.messageName)
        installScripts()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.autoresizingMask = placeholder.autoresizingMask
        placeholder.superview?.replaceSubview(placeholder, with: webView)
    }

    /// Frees the script handler. Call when the window closes.
    @objc func tearDown() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: PreviewController.messageName)
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    // MARK: Scripts

    /// What the page may know about the settings. Set before any page script runs.
    private var appliedSettings: String?

    private func settingsSource() -> String {
        let remote = ThemeService.shared.currentConfig().charts.vegaLiteRemoteData
        return "window.MacDownSettings = {vegaRemoteData: \(remote ? "true" : "false")};"
    }

    /// (Re)installs the scripts that run in every page. User scripts cannot be changed
    /// one by one, so all are replaced.
    private func installScripts() {
        let content = webView.configuration.userContentController
        let settings = settingsSource()
        content.removeAllUserScripts()
        content.addUserScript(WKUserScript(source: PreviewScripts.bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        content.addUserScript(WKUserScript(source: settings, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        content.addUserScript(WKUserScript(source: PreviewScripts.metrics, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        appliedSettings = settings
    }

    // MARK: Loading

    @objc func loadHTML(_ html: String, baseURL: URL?) {
        if settingsSource() != appliedSettings { installScripts() }
        isLoading = true
        lastLoad = (html, baseURL)
        webView.loadHTMLString(PreviewURL.rewrite(html: html), baseURL: baseURL.map(PreviewURL.baseURL(for:)))
    }

    // MARK: Page control

    @objc(scrollToY:)
    func scroll(toY y: CGFloat) {
        let target = max(0, y)
        webView.evaluateJavaScript("window.scrollTo(0, \(String(format: "%.1f", target)));", completionHandler: nil)
    }

    @objc func clearSelection() {
        webView.evaluateJavaScript("window.getSelection().removeAllRanges();", completionHandler: nil)
    }

    @objc func setZoom(_ scale: CGFloat) {
        if scale > 0, abs(webView.pageZoom - scale) > 0.001 { webView.pageZoom = scale }
    }

    @objc func fetchTextCount(_ completion: @escaping (Int, Int, Int) -> Void) {
        webView.evaluateJavaScript("document.body ? document.body.innerText : ''") { result, _ in
            let count = TextCount(of: (result as? String) ?? "")
            completion(count.words, count.characters, count.charactersNoSpaces)
        }
    }

    @objc func fetchBackgroundColor(_ completion: @escaping (NSColor?) -> Void) {
        let script = """
        (function(){ function c(e){return e?getComputedStyle(e).backgroundColor:'';}
        var b=c(document.body); return (b && b!=='rgba(0, 0, 0, 0)' && b!=='transparent') ? b : c(document.documentElement); })()
        """
        webView.evaluateJavaScript(script) { result, _ in completion(CSSColor.parse((result as? String) ?? "")) }
    }

    @objc(printOperationWithPrintInfo:)
    func printOperation(with info: NSPrintInfo) -> NSPrintOperation {
        let operation = webView.printOperation(with: info)
        // WebKit needs a frame for the page it prints.
        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        let height = info.paperSize.height - info.topMargin - info.bottomMargin
        operation.view?.frame = NSRect(x: 0, y: 0, width: max(width, 100), height: max(height, 100))
        return operation
    }
}

// MARK: - Navigation

extension PreviewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard action.navigationType == .linkActivated, let url = action.request.url else {
            return decisionHandler(.allow)
        }
        let allow = delegate?.preview(self, shouldNavigateTo: PreviewURL.fileURL(for: url)) ?? true
        // A link that opens a new window (target=_blank) is handled by the delegate; never open it here.
        decisionHandler(allow && action.targetFrame != nil ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finishLoading() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finishLoading() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finishLoading() }

    private func finishLoading() {
        isLoading = false
        crashReloads = 0
        delegate?.previewDidFinishLoading(self)
    }

    /// The web content process can be killed by the system (memory pressure). Show the page again.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard let last = lastLoad, crashReloads < 3 else { return }
        crashReloads += 1
        loadHTML(last.html, baseURL: last.base)
    }
}

extension PreviewController: WKUIDelegate {
    /// `target=_blank` links: let the app decide, never open a window.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url {
            _ = delegate?.preview(self, shouldNavigateTo: PreviewURL.fileURL(for: url))
        }
        return nil
    }
}

// MARK: - Messages from the page

extension PreviewController: WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "mathjax":
            delegate?.previewMathJaxDidFinish(self)
        case "metrics":
            headerLocations = (body["headers"] as? [Double] ?? []).map { NSNumber(value: $0) }
            contentHeight = CGFloat(body["height"] as? Double ?? 0)
            visibleHeight = CGFloat(body["visible"] as? Double ?? 0)
            scrollY = CGFloat(body["y"] as? Double ?? 0)
        case "scroll":
            scrollY = CGFloat(body["y"] as? Double ?? 0)
            delegate?.previewDidScroll(self)
        default: break
        }
    }
}

/// `WKUserContentController` keeps its handlers alive; this stops a retain cycle.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

// MARK: - Scripts

enum PreviewScripts {
    /// Gives the page the `MathJaxListener` object that `MathJax/init.js` calls when typesetting is done.
    static let bridge = """
    window.MathJaxListener = { invokeCallbackForKey_: function (key) {
      window.webkit.messageHandlers.macdown.postMessage({type: 'mathjax', key: String(key)});
    } };
    """

    /// Reports where headings are and how tall the page is, for scroll sync.
    /// Reports are merged: at most one every 50 ms.
    static let metrics = """
    (function () {
      var post = function (m) { window.webkit.messageHandlers.macdown.postMessage(m); };
      var pending = false, scrollPending = false;
      function report() {
        pending = false;
        var y = window.scrollY;
        var nodes = document.querySelectorAll('h1, h2, h3, h4, h5, h6, img:only-child');
        var tops = [];
        for (var i = 0; i < nodes.length; i++) { tops.push(nodes[i].getBoundingClientRect().top + y); }
        post({type: 'metrics', headers: tops, height: document.documentElement.scrollHeight,
              visible: window.innerHeight, y: y});
      }
      function schedule() { if (!pending) { pending = true; setTimeout(report, 50); } }
      window.addEventListener('load', schedule);
      window.addEventListener('resize', schedule);
      window.addEventListener('scroll', function () {
        // A timer, not requestAnimationFrame: hidden or covered windows do not run animation frames.
        if (!scrollPending) { scrollPending = true; setTimeout(function () {
          scrollPending = false; post({type: 'scroll', y: window.scrollY}); }, 50); }
      }, {passive: true});
      if (window.ResizeObserver) { new ResizeObserver(schedule).observe(document.documentElement); }
      schedule();
    })();
    """
}
