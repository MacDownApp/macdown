import SwiftUI
import PDFKit

/// A PDF from the vault: scrolls continuously, text can be selected, and the system find bar works.
struct PDFScreen: View {
    let item: VaultStore.PDFItem
    @State private var pageText = ""
    @State private var findRequest = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            PDFKitView(item: item, findRequest: findRequest, pageText: $pageText)
                .ignoresSafeArea(edges: .bottom)
            if !pageText.isEmpty {
                Text(pageText)
                    .font(.footnote.monospacedDigit())
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 14)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { findRequest += 1 } label: { Image(systemName: "magnifyingglass") }
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let item: VaultStore.PDFItem
    let findRequest: Int
    @Binding var pageText: String

    func makeCoordinator() -> Coordinator { Coordinator(pageText: $pageText) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.pageBreakMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        view.backgroundColor = .systemGray5
        view.isFindInteractionEnabled = true
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.pageChanged(_:)),
                                               name: .PDFViewPageChanged, object: view)
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.shownPath != item.path {
            coordinator.shownPath = item.path
            view.document = item.document
            if let page = item.document.page(at: max(0, min(item.page, item.document.pageCount) - 1)) { view.go(to: page) }
            coordinator.pageChanged(nil)
        }
        if coordinator.lastFindRequest != findRequest {
            coordinator.lastFindRequest = findRequest
            view.findInteraction.presentFindNavigator(showingReplace: false)
        }
    }

    final class Coordinator: NSObject {
        weak var view: PDFView?
        var shownPath = ""
        var lastFindRequest = 0
        @Binding var pageText: String

        init(pageText: Binding<String>) { _pageText = pageText }

        @objc func pageChanged(_ note: Notification?) {
            guard let view = view, let document = view.document, let page = view.currentPage else { return }
            let text = "\(document.index(for: page) + 1) / \(document.pageCount)"
            DispatchQueue.main.async { self.pageText = text }
        }
    }
}
