@testable import FileCore
@testable import Preview
import Testing

@Test func moduleLoads() {
    #expect(PreviewModule.moduleName == "Preview")
}

@Suite("PreviewRouter")
struct PreviewRouterTests {
    @Test func markdownRendersAsMarkdown() {
        let formats = FileFormatRegistry.defaultFormats
        let markdown = formats.first { $0.id == "markdown" }
        #expect(markdown != nil)
        #expect(PreviewRouter.previewKind(for: markdown ?? plaintextFallback()) == .markdown)
    }

    @Test func htmlRendersAsHTML() {
        let formats = FileFormatRegistry.defaultFormats
        let html = formats.first { $0.id == "html" }
        #expect(html != nil)
        #expect(PreviewRouter.previewKind(for: html ?? plaintextFallback()) == .html)
    }

    @Test func jsonPreviewIsToggleable() {
        let formats = FileFormatRegistry.defaultFormats
        let json = formats.first { $0.id == "json" }
        #expect(json != nil)
        #expect(PreviewRouter.previewKind(for: json ?? plaintextFallback()) == .none)
    }

    @Test func plaintextHasNoPreview() {
        let formats = FileFormatRegistry.defaultFormats
        let plaintext = formats.first { $0.id == "plaintext" }
        #expect(plaintext != nil)
        #expect(PreviewRouter.previewKind(for: plaintext ?? plaintextFallback()) == .none)
    }
}

private func plaintextFallback() -> FileFormat {
    FileFormat(
        id: "plaintext",
        name: "Plain Text",
        utType: .plainText,
        extensions: ["txt"]
    )
}

@Suite("PreviewSecurity")
struct PreviewSecurityTests {
    @Test func injectsCSPIntoExistingHead() {
        let html = "<html><head><title>t</title></head><body>hi</body></html>"
        let out = PreviewSecurity.hardenedHTMLDocument(from: html)
        #expect(out.contains("Content-Security-Policy"))
        #expect(out.contains("default-src 'none'"))
        // The CSP must appear before the document's own <title>.
        let csp = out.range(of: "Content-Security-Policy")
        let title = out.range(of: "<title>")
        #expect(csp != nil)
        #expect(title != nil)
        if let csp, let title {
            #expect(csp.lowerBound < title.lowerBound)
        }
    }

    @Test func addsHeadWhenOnlyHTMLTagPresent() {
        let html = "<html><body>content</body></html>"
        let out = PreviewSecurity.hardenedHTMLDocument(from: html)
        #expect(out.contains("<html><head>"))
        #expect(out.contains("Content-Security-Policy"))
        #expect(out.contains("<body>content</body>"))
    }

    @Test func wrapsBareFragment() {
        let html = "<p>hello</p>"
        let out = PreviewSecurity.hardenedHTMLDocument(from: html)
        #expect(out.hasPrefix("<!DOCTYPE html>"))
        #expect(out.contains("Content-Security-Policy"))
        #expect(out.contains("<p>hello</p>"))
    }

    @Test func doesNotMatchHeaderTag() {
        // <header> must not be mistaken for <head>; a real <head> is added
        // after <html> instead.
        let html = "<html><body><header>menu</header></body></html>"
        let out = PreviewSecurity.hardenedHTMLDocument(from: html)
        #expect(out.contains("<html><head>"))
        #expect(out.contains("<header>menu</header>"))
        #expect(out.contains("Content-Security-Policy"))
    }

    @Test func matchesHeadWithAttributes() {
        let html = "<html><head class=\"x\"><title>t</title></head><body>hi</body></html>"
        let out = PreviewSecurity.hardenedHTMLDocument(from: html)
        // Injected right after the opening <head ...> tag.
        #expect(out.contains("<head class=\"x\"><meta http-equiv=\"Content-Security-Policy\""))
    }
}
