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

extension Color {
    /// `#rrggbb` (anything else gives the default blue).
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0x0A84FF
        if digits.count == 6 { Scanner(string: digits).scanHexInt64(&value) }
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}
