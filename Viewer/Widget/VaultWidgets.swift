import WidgetKit
import SwiftUI
import ViewerCore

@main
struct VaultWidgets: WidgetBundle {
    var body: some Widget {
        NoteShortcutWidget()
        FolderNotesWidget()
    }
}

/// What a widget can know: the snapshot the app wrote, or nothing yet.
enum WidgetData {
    static func load() -> WidgetSnapshot? { SnapshotStore.appGroup()?.read() }
}
