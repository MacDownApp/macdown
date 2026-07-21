import SwiftUI
import Workspace

struct SidebarView: View {
    @Bindable var model: WorkspaceModel

    var body: some View {
        List {
            Section {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { model.isSectionExpanded(.folder) },
                        set: { model.setSectionExpanded(.folder, $0) }
                    )
                ) {
                    folderContent
                } label: {
                    Label("Folder", systemImage: "folder")
                }
            }

            Section {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { model.isSectionExpanded(.outline) },
                        set: { model.setSectionExpanded(.outline, $0) }
                    )
                ) {
                    outlineContent
                } label: {
                    Label("Outline", systemImage: "list.bullet")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    }

    @ViewBuilder
    private var folderContent: some View {
        if let folderURL = model.folderURL {
            Text(folderURL.lastPathComponent)
                .lineLimit(1)
        } else {
            Text("No folder opened")
                .foregroundStyle(.secondary)
        }
    }

    private var outlineContent: some View {
        Text("Outline will appear here")
            .foregroundStyle(.secondary)
    }
}
