import FileCore
import MarkdownEngine
import Preview
import SwiftUI
import WebKit

struct ContentAreaView: View {
    let document: FileCore.FileDocument?

    var body: some View {
        Group {
            if let document {
                documentContent(document)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func documentContent(_ document: FileCore.FileDocument) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack(spacing: 10) {
                Image(systemName: documentIcon(for: document.format.id))
                    .foregroundStyle(.secondary)

                Text(title(for: document))
                    .font(.system(size: 13, weight: .semibold))

                if document.fileURL == nil {
                    Text("— Save As… ⌘⇧S to name this document")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Format badge
                Text(document.format.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            Divider()

            // Source / preview split
            DocumentEditorSplitView(document: document)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.quaternary)

            Text("No Document")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ShortcutHint(shortcut: "⌘N", label: "New File")
                ShortcutHint(shortcut: "⌘O", label: "Open File")
            }
        }
    }

    private func title(for document: FileCore.FileDocument) -> String {
        document.fileURL?.lastPathComponent ?? "Untitled"
    }

    private func documentIcon(for formatID: String) -> String {
        let sourceIcons: Set = [
            "javascript", "typescript", "python", "ruby",
            "swift", "c", "bash", "sql",
        ]
        if sourceIcons.contains(formatID) {
            return "chevron.left.forwardslash.chevron.right"
        }
        switch formatID {
        case "markdown": return "richtext"
        case "html": return "chevron.left.forwardslash.chevron.right"
        case "json": return "curlybraces"
        default: return "doc.text"
        }
    }
}

// MARK: - Source / preview split

private struct DocumentEditorSplitView: View {
    let document: FileCore.FileDocument

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Source pane (left)
                SourcePane(text: document.text, format: document.format)
                    .frame(width: geometry.size.width / 2)

                // Divider
                Rectangle()
                    .fill(.separator)
                    .frame(width: 1)

                // Preview pane (right)
                previewPane
                    .frame(width: geometry.size.width / 2 - 1)
            }
        }
    }

    @ViewBuilder
    private var previewPane: some View {
        switch PreviewRouter.previewKind(for: document.format) {
        case .markdown:
            MarkdownPreviewView(text: document.text)
        case .html:
            HTMLPreviewView(text: document.text)
        case .none:
            NoPreviewView(formatName: document.format.name)
        }
    }
}

// MARK: - Source pane

private struct SourcePane: View {
    let text: String
    let format: FileFormat

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? " " : text)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Markdown preview

private struct MarkdownPreviewView: View {
    let text: String

    var body: some View {
        ScrollView {
            MarkdownPreviewBody(text: text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(Color(.textBackgroundColor))
    }
}

// MARK: - HTML preview

private struct HTMLPreviewView: NSViewRepresentable {
    let text: String

    func makeNSView(context _: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = false
        return WKWebView(frame: .zero, configuration: configuration)
    }

    func updateNSView(_ webView: WKWebView, context _: Context) {
        // Inject a restrictive CSP so a previewed file cannot load remote
        // resources (defence-in-depth on top of the disabled JavaScript above).
        webView.loadHTMLString(PreviewSecurity.hardenedHTMLDocument(from: text), baseURL: nil)
    }
}

// MARK: - No preview

private struct NoPreviewView: View {
    let formatName: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.slash")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text("No preview for \(formatName)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helpers

private struct ShortcutHint: View {
    let shortcut: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Text(shortcut)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
