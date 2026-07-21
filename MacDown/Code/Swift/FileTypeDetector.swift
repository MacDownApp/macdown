import Foundation

// MARK: - File Type Enumeration

enum DocumentFileType: Equatable, Hashable {
    case markdown
    case rmarkdown
    case latex
    case unknown
}

// MARK: - File Type Detection

final class FileTypeDetector {

    /// Detects file type from URL
    static func detect(from url: URL) -> DocumentFileType {
        let fileExtension = url.pathExtension.lowercased()
        return detect(from: fileExtension)
    }

    /// Detects file type from file extension
    static func detect(from fileExtension: String) -> DocumentFileType {
        let ext = fileExtension.lowercased()

        switch ext {
        case "md", "markdown":
            return .markdown
        case "rmd", "Rmd", "rmarkdown":
            return .rmarkdown
        case "tex", "latex":
            return .latex
        default:
            return .unknown
        }
    }

    /// Detects file type from UTI (Uniform Type Identifier)
    static func detect(from uti: String) -> DocumentFileType {
        switch uti {
        case "net.daringfireball.markdown":
            return .markdown
        case "com.macdown.rmarkdown":
            return .rmarkdown
        case "com.macdown.latex":
            return .latex
        case "public.plain-text":
            return .markdown
        default:
            return .unknown
        }
    }

    /// Gets default file extension for file type
    static func fileExtension(for fileType: DocumentFileType) -> String {
        switch fileType {
        case .markdown:
            return "md"
        case .rmarkdown:
            return "rmd"
        case .latex:
            return "tex"
        case .unknown:
            return "txt"
        }
    }

    /// Gets human-readable name for file type
    static func displayName(for fileType: DocumentFileType) -> String {
        switch fileType {
        case .markdown:
            return "Markdown"
        case .rmarkdown:
            return "RMarkdown"
        case .latex:
            return "LaTeX"
        case .unknown:
            return "Text"
        }
    }

    /// Checks if file type supports preview
    static func supportsPreview(_ fileType: DocumentFileType) -> Bool {
        switch fileType {
        case .markdown, .rmarkdown, .latex:
            return true
        case .unknown:
            return false
        }
    }
}

// MARK: - File Type MIME Types

extension DocumentFileType {
    var mimeType: String {
        switch self {
        case .markdown:
            return "text/x-markdown"
        case .rmarkdown:
            return "text/x-rmarkdown"
        case .latex:
            return "application/x-latex"
        case .unknown:
            return "text/plain"
        }
    }
}

// MARK: - File Type Description

extension DocumentFileType: CustomStringConvertible {
    var description: String {
        FileTypeDetector.displayName(for: self)
    }
}
