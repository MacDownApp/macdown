import WidgetKit
import SwiftUI
import ViewerCore

// Small widget: a shortcut to one note.

struct NoteEntry: TimelineEntry {
    enum State { case noVault, missing, ready(WidgetSnapshot.Note, vault: String) }
    let date: Date
    let state: State
    var accent: String? = nil
}

struct NoteProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NoteEntry {
        NoteEntry(date: Date(), state: .ready(.init(path: "Projects/Plan.md", title: "Project plan", modified: Date().timeIntervalSince1970), vault: "Vault"))
    }

    func snapshot(for configuration: SelectNoteIntent, in context: Context) async -> NoteEntry { entry(for: configuration) }

    func timeline(for configuration: SelectNoteIntent, in context: Context) async -> Timeline<NoteEntry> {
        // The app refreshes widgets whenever the vault changes; this is only a safety net.
        Timeline(entries: [entry(for: configuration)], policy: .after(Date().addingTimeInterval(3600)))
    }

    private func entry(for configuration: SelectNoteIntent) -> NoteEntry {
        guard let snapshot = WidgetData.load() else { return NoteEntry(date: Date(), state: .noVault) }
        if let chosen = configuration.note {
            guard let note = snapshot.notes[chosen.id] else { return NoteEntry(date: Date(), state: .missing) }
            return NoteEntry(date: Date(), state: .ready(note, vault: snapshot.vaultName), accent: snapshot.accent)
        }
        guard let latest = snapshot.recentNotes(limit: 1).first else { return NoteEntry(date: Date(), state: .missing) }
        return NoteEntry(date: Date(), state: .ready(latest, vault: snapshot.vaultName), accent: snapshot.accent)
    }
}

struct NoteShortcutView: View {
    let entry: NoteEntry

    var body: some View {
        switch entry.state {
        case .noVault:
            message("Open Vault Viewer once to set up this widget.")
        case .missing:
            message("This note was not found. Choose another one.")
        case let .ready(note, vault):
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "doc.text.fill").font(.title2).foregroundStyle(.tint)
                Spacer(minLength: 0)
                Text(note.title).font(.headline).lineLimit(3).minimumScaleFactor(0.8)
                Text(note.folder.isEmpty ? vault : note.folder).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if let date = note.modifiedDate {
                    Text(date, style: .relative).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetURL(DeepLink.url(forNote: note.path))
        }
    }

    private func message(_ text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.text").font(.title2).foregroundStyle(.secondary)
            Text(text).font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
    }
}

struct NoteShortcutWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "NoteShortcut", intent: SelectNoteIntent.self, provider: NoteProvider()) { entry in
            NoteShortcutView(entry: entry).tint(entry.accent.map { Color(hex: $0) }).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Note")
        .description("Opens one note of your vault.")
        .supportedFamilies([.systemSmall])
    }
}
