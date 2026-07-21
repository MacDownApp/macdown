import FileCore
import MarkdownEngine
import SwiftUI

/// Preview — format router and lightweight preview views for the workspace shell.
///
/// See planning/epics/ and planning/MIGRATION_PLAN.md § 4 for the full role.
/// For EPIC-02 the preview is read-only and intentionally simple: Markdown is
/// rendered to attributed text via `MarkdownEngine`, HTML is shown in a
/// `WKWebView`, and other formats display a placeholder. Richer preview
/// contributions (math, diagrams, scroll sync) arrive in later epics.
public enum PreviewModule {
    public static let moduleName = "Preview"
}

/// The kind of preview a format supports in the workspace shell.
public enum PreviewKind: Sendable, Equatable {
    case markdown
    case html
    case none
}

/// Routes `FileFormat` to the preview kind used by the content area.
public enum PreviewRouter {
    public static func previewKind(for format: FileFormat) -> PreviewKind {
        switch format.id {
        case "markdown":
            .markdown
        case "html":
            .html
        default:
            format.previewCapability == .rendered ? .markdown : .none
        }
    }
}

/// A SwiftUI view that renders Markdown source as attributed text.
///
/// This is a temporary EPIC-02 placeholder for the native Textual-based preview
/// planned in E07. It uses `MarkdownEngine` to produce a plain attributed
/// string so the split editor/preview layout is visible immediately.
public struct MarkdownPreviewBody: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(attributedContent)
            .font(.system(.body))
            .textSelection(.enabled)
    }

    /// `@MainActor` so it can call `MarkdownEngine.renderAttributed`, which
    /// builds AppKit types and is main-actor isolated. `body` is already on the
    /// main actor, so reading this property from it is free.
    @MainActor
    private var attributedContent: AttributedString {
        let nsAttributed = MarkdownEngine.renderAttributed(text)
            ?? NSAttributedString(string: text)
        return AttributedString(nsAttributed)
    }
}
