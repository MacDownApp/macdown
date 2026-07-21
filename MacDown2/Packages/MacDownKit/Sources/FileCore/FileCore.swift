/// FileCore — file format registry, FileStore IO, and FileDocument lifecycle.
///
/// See `planning/epics/EPIC-01-file-format-core.md` for the full scope.
///
/// The module marker is named `FileCoreModule` instead of `FileCore` because
/// `FileCore` shadows the module name, which made `FileCore.FileDocument`
/// unresolvable in the app target (SwiftUI also defines a `FileDocument`
/// protocol). Keep the marker name stable; refer to the module by name only
/// when necessary.
public enum FileCoreModule {
    public static let moduleName = "FileCore"
}
