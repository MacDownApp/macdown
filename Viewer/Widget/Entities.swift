import AppIntents
import ViewerCore

// MARK: Note

struct NoteEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Note"
    static var defaultQuery = NoteQuery()

    /// The note's path in the vault.
    var id: String
    var title: String
    var folder: String

    var displayRepresentation: DisplayRepresentation {
        folder.isEmpty ? DisplayRepresentation(title: "\(title)")
                       : DisplayRepresentation(title: "\(title)", subtitle: "\(folder)")
    }

    init(_ note: WidgetSnapshot.Note) { id = note.path; title = note.title; folder = note.folder }
}

struct NoteQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [NoteEntity] {
        guard let snapshot = WidgetData.load() else { return [] }
        return identifiers.compactMap { snapshot.notes[$0] }.map(NoteEntity.init)
    }

    func suggestedEntities() async throws -> [NoteEntity] {
        (WidgetData.load()?.recentNotes(limit: 40) ?? []).map(NoteEntity.init)
    }

    func entities(matching string: String) async throws -> [NoteEntity] {
        (WidgetData.load()?.searchNotes(string, limit: 40) ?? []).map(NoteEntity.init)
    }
}

// MARK: Folder

struct FolderEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Folder"
    static var defaultQuery = FolderQuery()

    /// The folder's path in the vault; the vault itself is the empty string.
    var id: String
    var name: String
    var isVault: Bool

    var displayRepresentation: DisplayRepresentation {
        isVault ? DisplayRepresentation(title: "\(name)", subtitle: "Whole vault")
                : DisplayRepresentation(title: "\(name)", subtitle: "\(id)")
    }

    init(_ folder: WidgetSnapshot.Folder) { id = folder.path; name = folder.name; isVault = folder.path.isEmpty }
}

struct FolderQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [FolderEntity] {
        guard let snapshot = WidgetData.load() else { return [] }
        return identifiers.compactMap { snapshot.folders[$0] }.map(FolderEntity.init)
    }

    func suggestedEntities() async throws -> [FolderEntity] {
        (WidgetData.load()?.allFolders ?? []).prefix(200).map(FolderEntity.init)
    }

    func entities(matching string: String) async throws -> [FolderEntity] {
        let query = string.lowercased()
        return (WidgetData.load()?.allFolders ?? []).filter { $0.path.lowercased().contains(query) }.prefix(100).map(FolderEntity.init)
    }
}

// MARK: Configuration

struct SelectNoteIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Note"
    static var description = IntentDescription("The note this widget opens. Without one, it shows the note you changed last.")

    @Parameter(title: "Note")
    var note: NoteEntity?
}

struct SelectFolderIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Folder"
    static var description = IntentDescription("The folder to list. Its notes and its sub-folders' notes are shown.")

    @Parameter(title: "Folder")
    var folder: FolderEntity?
}
