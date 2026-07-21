@testable import FileCore
import Foundation
import Testing
@testable import Workspace

@MainActor
@Suite("WorkspaceModelFileOperations")
struct WorkspaceModelFileTests {
    // MARK: - Open file

    @Test func openFileLoadsDocument() async {
        let directory = temporaryDirectory()
        defer { cleanup(directory) }
        let url = directory.appendingPathComponent("doc.md")
        try? FileStore().write("# Hello", to: url)

        let panel = FakeFilePanelProvider()
        panel.nextFileURL = url

        let model = WorkspaceModel(stateStore: FakeStateStore(), panel: panel)
        await model.openFile()

        #expect(model.activeDocument?.text == "# Hello")
        #expect(model.activeDocument?.format.id == "markdown")
        #expect(model.activeDocument?.state == .clean)
    }

    @Test func openFileCancelledLeavesWorkspaceEmpty() async {
        let panel = FakeFilePanelProvider()
        let model = WorkspaceModel(stateStore: FakeStateStore(), panel: panel)
        await model.openFile()
        #expect(model.activeDocument == nil)
    }

    @Test func openFileWhileDirtyPromptsClose() async {
        let directory = temporaryDirectory()
        defer { cleanup(directory) }
        let firstURL = directory.appendingPathComponent("first.md")
        let secondURL = directory.appendingPathComponent("second.md")
        try? FileStore().write("first", to: firstURL)
        try? FileStore().write("second", to: secondURL)

        let panel = FakeFilePanelProvider()
        panel.nextFileURL = firstURL

        let model = WorkspaceModel(stateStore: FakeStateStore(), panel: panel)
        await model.openFile()
        model.activeDocument = model.activeDocument?.updatingText("edited")

        panel.nextFileURL = secondURL
        await model.openFile()

        #expect(model.pendingClose == true)
        #expect(model.activeDocument?.text == "edited")
    }

    @Test func openFileContinuesAfterDirtyClose() async {
        let directory = temporaryDirectory()
        defer { cleanup(directory) }
        let firstURL = directory.appendingPathComponent("first.md")
        let secondURL = directory.appendingPathComponent("second.md")
        try? FileStore().write("first", to: firstURL)
        try? FileStore().write("second", to: secondURL)

        let panel = FakeFilePanelProvider()
        panel.nextFileURL = firstURL

        let model = WorkspaceModel(stateStore: FakeStateStore(), panel: panel)
        await model.openFile()
        model.activeDocument = model.activeDocument?.updatingText("edited")

        panel.nextFileURL = secondURL
        await model.openFile()
        await model.resolveClose(.discard)

        #expect(model.pendingClose == false)
        #expect(model.activeDocument?.text == "second")
    }

    @Test func openFileCancelledAbortsOpen() async {
        let directory = temporaryDirectory()
        defer { cleanup(directory) }
        let firstURL = directory.appendingPathComponent("first.md")
        try? FileStore().write("first", to: firstURL)

        let panel = FakeFilePanelProvider()
        panel.nextFileURL = firstURL

        let model = WorkspaceModel(stateStore: FakeStateStore(), panel: panel)
        await model.openFile()
        model.activeDocument = model.activeDocument?.updatingText("edited")

        await model.openFile()
        await model.resolveClose(.cancel)

        #expect(model.pendingClose == false)
        #expect(model.activeDocument?.text == "edited")
    }

    // MARK: - Save / Save As

    @Test func saveExistingFileWritesToDisk() async throws {
        let directory = temporaryDirectory()
        defer { cleanup(directory) }
        let url = directory.appendingPathComponent("doc.md")
        try? FileStore().write("old", to: url)

        let panel = FakeFilePanelProvider()
        panel.nextFileURL = url

        let model = WorkspaceModel(stateStore: FakeStateStore(), panel: panel)
        await model.openFile()
        model.activeDocument = model.activeDocument?.updatingText("new")

        await model.save()

        #expect(model.activeDocument?.state == .clean)
        let (text, _) = try FileStore().read(from: url)
        #expect(text == "new")
    }

    @Test func saveUntitledUsesSavePanel() async throws {
        let directory = temporaryDirectory()
        defer { cleanup(directory) }
        let url = directory.appendingPathComponent("saved.md")

        let panel = FakeFilePanelProvider()
        panel.nextSaveURL = url

        let model = WorkspaceModel(stateStore: FakeStateStore(), panel: panel)
        await model.newDocument()
        model.activeDocument = model.activeDocument?.updatingText("content")

        await model.save()

        #expect(model.activeDocument?.fileURL == url)
        #expect(model.activeDocument?.state == .clean)
        let (text, _) = try FileStore().read(from: url)
        #expect(text == "content")
    }

    @Test func saveCancelledKeepsDocumentOpenAndDirty() async {
        let panel = FakeFilePanelProvider()
        let model = WorkspaceModel(stateStore: FakeStateStore(), panel: panel)
        await model.newDocument()
        model.activeDocument = model.activeDocument?.updatingText("content")

        await model.save()

        #expect(model.activeDocument?.fileURL == nil)
        #expect(model.activeDocument?.state == .dirty)
    }

    @Test func saveWithoutDocumentSetsError() async {
        let model = WorkspaceModel(stateStore: FakeStateStore())
        await model.save()

        if case .noActiveDocument = model.lastError {
            // pass
        } else {
            Issue.record("Expected .noActiveDocument, got \(String(describing: model.lastError))")
        }
    }

    @Test func saveToReadOnlyDirectoryFails() async {
        let directory = temporaryDirectory()
        defer { cleanup(directory) }
        let url = directory.appendingPathComponent("doc.md")
        try? FileStore().write("content", to: url)

        var attributes = try? FileManager.default.attributesOfItem(atPath: directory.path)
        attributes?[FileAttributeKey.posixPermissions] = 0o555
        try? FileManager.default.setAttributes(attributes ?? [:], ofItemAtPath: directory.path)
        defer {
            var reset = try? FileManager.default.attributesOfItem(atPath: directory.path)
            reset?[FileAttributeKey.posixPermissions] = 0o755
            try? FileManager.default.setAttributes(reset ?? [:], ofItemAtPath: directory.path)
        }

        let panel = FakeFilePanelProvider()
        panel.nextFileURL = url

        let model = WorkspaceModel(stateStore: FakeStateStore(), panel: panel)
        await model.openFile()
        model.activeDocument = model.activeDocument?.updatingText("edited")

        await model.save()

        #expect(model.activeDocument?.state == .dirty)
        if case .saveFailed = model.lastError {
            // pass
        } else {
            Issue.record("Expected .saveFailed, got \(String(describing: model.lastError))")
        }
    }
}
