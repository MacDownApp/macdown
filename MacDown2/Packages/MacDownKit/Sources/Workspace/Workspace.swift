/// Workspace — workspace shell model, command routing, and window state persistence.
///
/// See `planning/epics/EPIC-02-workspace-shell.md` and
/// `planning/epic-02-implementation.md` for the full scope.
///
/// The module marker is named `WorkspaceModule` instead of `Workspace` because
/// `Workspace` shadows the module name and collides with the `@testable
/// import Workspace` used by tests. Keep the marker name stable.
public enum WorkspaceModule {
    public static let moduleName = "Workspace"
}
