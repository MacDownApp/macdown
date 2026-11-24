import WidgetKit
import SwiftUI
import ViewerCore

// Medium and large widget: a folder, with its notes and a section per sub-folder.

struct FolderEntry: TimelineEntry {
    enum State { case noVault, missing, ready(title: String, sections: [WidgetSection]) }
    let date: Date
    let state: State
    let family: WidgetFamily
}

struct FolderProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FolderEntry {
        let note = WidgetSnapshot.Note(path: "Folder/Note.md", title: "A note", modified: Date().timeIntervalSince1970)
        return FolderEntry(date: Date(), state: .ready(title: "Folder", sections: [WidgetSection(title: "Section", folderPath: "Folder", notes: [note, note], hiddenCount: 0)]), family: context.family)
    }

    func snapshot(for configuration: SelectFolderIntent, in context: Context) async -> FolderEntry { entry(for: configuration, family: context.family) }

    func timeline(for configuration: SelectFolderIntent, in context: Context) async -> Timeline<FolderEntry> {
        Timeline(entries: [entry(for: configuration, family: context.family)], policy: .after(Date().addingTimeInterval(3600)))
    }

    /// How many text lines fit: a section title and a note are one line each.
    static func lineBudget(_ family: WidgetFamily) -> Int { family == .systemLarge ? 13 : 5 }

    private func entry(for configuration: SelectFolderIntent, family: WidgetFamily) -> FolderEntry {
        guard let snapshot = WidgetData.load() else { return FolderEntry(date: Date(), state: .noVault, family: family) }
        let path = configuration.folder?.id ?? ""
        guard let folder = snapshot.folders[path] else { return FolderEntry(date: Date(), state: .missing, family: family) }
        let sections = WidgetLayout.sections(for: path, in: snapshot, lineBudget: Self.lineBudget(family))
        return FolderEntry(date: Date(), state: .ready(title: folder.name, sections: sections), family: family)
    }
}

struct FolderNotesView: View {
    let entry: FolderEntry

    var body: some View {
        switch entry.state {
        case .noVault: message("Open Vault Viewer once to set up this widget.")
        case .missing: message("This folder was not found. Choose another one.")
        case let .ready(title, sections):
            if sections.isEmpty {
                message("No notes in “\(title)”.")
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.title.uppercased())
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tint).lineLimit(1)
                            ForEach(section.notes, id: \.path) { note in
                                Link(destination: DeepLink.url(forNote: note.path)) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.text").font(.caption2).foregroundStyle(.secondary)
                                        Text(note.title).font(.subheadline).lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                }
                                .foregroundStyle(.primary)
                            }
                            if section.hiddenCount > 0 {
                                Text("+\(section.hiddenCount) more").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func message(_ text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "folder").font(.title2).foregroundStyle(.secondary)
            Text(text).font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FolderNotesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "FolderNotes", intent: SelectFolderIntent.self, provider: FolderProvider()) { entry in
            FolderNotesView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Folder")
        .description("Lists the notes of a folder, grouped by sub-folder.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
