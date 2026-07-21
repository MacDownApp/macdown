import SwiftUI
import Workspace

public struct WorkspaceModelFocusedValue: FocusedValueKey {
    public typealias Value = WorkspaceModel
}

public extension FocusedValues {
    var workspaceModel: WorkspaceModel? {
        get { self[WorkspaceModelFocusedValue.self] }
        set { self[WorkspaceModelFocusedValue.self] = newValue }
    }
}

struct WorkspaceCommands: Commands {
    @FocusedValue(\.workspaceModel) private var model

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New File") {
                Task { await model?.newDocument() }
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open…") {
                Task { await model?.openFile() }
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Open Folder…") {
                Task { await model?.openFolder() }
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                Task { await model?.save() }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(model?.canSave != true)

            Button("Save As…") {
                Task { await model?.saveAs() }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(model?.hasActiveDocument != true)

            Button("Close Tab") {
                model?.requestCloseDocument()
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(model?.canClose != true)
        }

        CommandGroup(before: .sidebar) {
            Button("Toggle Sidebar") {
                if let model {
                    model.sidebarVisible.toggle()
                }
            }
            .keyboardShortcut("s", modifiers: [.control, .command])
        }
    }
}
