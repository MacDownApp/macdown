import Foundation

// MARK: - Renderer Protocol

/// Protocol for document rendering with async/await
protocol DocumentRenderer: AnyObject, Sendable {
    /// The content type this renderer accepts
    associatedtype ContentType: Sendable

    /// The output type this renderer produces
    associatedtype OutputType: Sendable

    /// Renders content asynchronously
    /// - Parameter content: The content to render
    /// - Returns: The rendered output
    func render(_ content: ContentType) async throws -> OutputType

    /// Current rendering status
    var isRendering: Bool { get }

    /// Cancels any ongoing rendering operation
    func cancelRendering()
}

// MARK: - Data Source Protocol

/// Provides content for rendering
protocol RenderDataSource: AnyObject {
    /// The document title
    var documentTitle: String { get }

    /// The document content
    var documentContent: String { get }
}

// MARK: - Delegate Protocol

/// Receives rendering results and status updates
protocol RenderDelegate: AnyObject {
    /// Called when rendering produces output
    /// - Parameters:
    ///   - renderer: The renderer that produced the output
    ///   - output: The rendered output
    func renderer<R: DocumentRenderer>(_ renderer: R,
                                      didProduceOutput: R.OutputType)

    /// Called when rendering starts
    func rendererDidStartRendering<R: DocumentRenderer>(_ renderer: R)

    /// Called when rendering finishes
    func rendererDidFinishRendering<R: DocumentRenderer>(_ renderer: R)

    /// Called when rendering fails
    func renderer<R: DocumentRenderer>(_ renderer: R,
                                     didFailWithError error: Error)
}

// MARK: - Base Renderer

/// Base class for document renderers
@MainActor
class BaseDocumentRenderer: NSObject, Sendable {
    weak var dataSource: RenderDataSource?
    weak var delegate: RenderDelegate?

    private(set) var isRendering: Bool = false
    private var renderTask: Task<Void, Never>?

    deinit {
        renderTask?.cancel()
    }

    func cancelRendering() {
        renderTask?.cancel()
        isRendering = false
    }

    /// Notifies delegate of rendering start
    nonisolated protected func notifyDidStartRendering() {
        Task { @MainActor in
            self.delegate?.rendererDidStartRendering(self)
        }
    }

    /// Notifies delegate of rendering finish
    nonisolated protected func notifyDidFinishRendering() {
        Task { @MainActor in
            self.isRendering = false
            self.delegate?.rendererDidFinishRendering(self)
        }
    }

    /// Notifies delegate of rendering error
    nonisolated protected func notifyDidFail(with error: Error) {
        Task { @MainActor in
            self.isRendering = false
            self.delegate?.renderer(self, didFailWithError: error)
        }
    }
}

// MARK: - Rendering Result

/// Result of a rendering operation
enum RenderingResult<T: Sendable>: Sendable {
    case success(T)
    case failure(Error)
    case cancelled

    var value: T? {
        switch self {
        case .success(let value):
            return value
        default:
            return nil
        }
    }

    var error: Error? {
        switch self {
        case .failure(let error):
            return error
        default:
            return nil
        }
    }

    var isCancelled: Bool {
        switch self {
        case .cancelled:
            return true
        default:
            return false
        }
    }
}

// MARK: - Rendering Configuration

/// Configuration for rendering
struct RenderingConfiguration: Sendable {
    /// Debounce delay in seconds
    let debounceDelay: TimeInterval

    /// Maximum time for rendering in seconds
    let timeout: TimeInterval?

    /// Whether to cache results
    let enableCaching: Bool

    /// Whether to render incrementally
    let incrementalRendering: Bool

    static let `default` = RenderingConfiguration(
        debounceDelay: 0.5,
        timeout: 30,
        enableCaching: true,
        incrementalRendering: false
    )
}
