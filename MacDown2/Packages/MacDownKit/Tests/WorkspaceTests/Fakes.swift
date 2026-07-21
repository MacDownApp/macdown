import Foundation
import Workspace

@MainActor
final class FakeStateStore: WorkspaceStateStoring {
    var sidebarVisible: Bool = true
    var sidebarSectionExpanded: [String: Bool] = [:]
}

func temporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func cleanup(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}
