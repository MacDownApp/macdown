@testable import FileCore
import Foundation
import Testing
@testable import Workspace

@Test func moduleLoads() {
    #expect(WorkspaceModule.moduleName == "Workspace")
}

// MARK: - Test suite

@MainActor
@Suite("WorkspaceModel")
struct WorkspaceModelTests {
    // MARK: - Command enablement

    @Test func newDocumentCreatesUntitledDocument() async {
        let model = WorkspaceModel(stateStore: FakeStateStore())
        await model.newDocument()

        #expect(model.hasActiveDocument)
        #expect(model.canClose)
        #expect(model.canSave == false)
        #expect(model.activeDocument?.fileURL == nil)
    }

    @Test func editingUntitledEnablesSave() async {
        let model = WorkspaceModel(stateStore: FakeStateStore())
        await model.newDocument()
        model.activeDocument = model.activeDocument?.updatingText("hello")

        #expect(model.canSave == true)
    }

    @Test func cleanSavedDocumentCannotSave() async {
        let model = WorkspaceModel(stateStore: FakeStateStore())
        await model.newDocument()
        #expect(model.canSave == false)
    }

    @Test func noDocumentDisablesSaveAndClose() {
        let model = WorkspaceModel(stateStore: FakeStateStore())
        #expect(model.hasActiveDocument == false)
        #expect(model.canSave == false)
        #expect(model.canClose == false)
    }

    // MARK: - New document

    @Test func newDocumentPromptsWhenDirty() async {
        let model = WorkspaceModel(stateStore: FakeStateStore())
        await model.newDocument()
        model.activeDocument = model.activeDocument?.updatingText("dirty")

        await model.newDocument()

        #expect(model.pendingClose == true)
        #expect(model.activeDocument?.text == "dirty")
    }

    @Test func newDocumentContinuesAfterDirtyClose() async {
        let model = WorkspaceModel(stateStore: FakeStateStore())
        await model.newDocument()
        model.activeDocument = model.activeDocument?.updatingText("dirty")

        await model.newDocument()
        await model.resolveClose(.discard)

        #expect(model.pendingClose == false)
        #expect(model.activeDocument?.text == "")
    }

    // MARK: - Close document

    @Test func closeCleanDocumentRemovesIt() async {
        let model = WorkspaceModel(stateStore: FakeStateStore())
        await model.newDocument()
        model.requestCloseDocument()

        #expect(model.activeDocument == nil)
        #expect(model.pendingClose == false)
    }

    @Test func closeDirtyDocumentPrompts() async {
        let model = WorkspaceModel(stateStore: FakeStateStore())
        await model.newDocument()
        model.activeDocument = model.activeDocument?.updatingText("dirty")
        model.requestCloseDocument()

        #expect(model.pendingClose == true)
        #expect(model.activeDocument != nil)
    }

    @Test func closePromptCancelKeepsDocumentDirty() async {
        let model = WorkspaceModel(stateStore: FakeStateStore())
        await model.newDocument()
        model.activeDocument = model.activeDocument?.updatingText("dirty")
        model.requestCloseDocument()

        await model.resolveClose(.cancel)

        #expect(model.pendingClose == false)
        #expect(model.activeDocument?.state == .dirty)
    }

    @Test func closePromptDiscardRemovesDocument() async {
        let model = WorkspaceModel(stateStore: FakeStateStore())
        await model.newDocument()
        model.activeDocument = model.activeDocument?.updatingText("dirty")
        model.requestCloseDocument()

        await model.resolveClose(.discard)

        #expect(model.activeDocument == nil)
        #expect(model.pendingClose == false)
    }

    @Test func closePromptSaveWritesAndCloses() async throws {
        let directory = temporaryDirectory()
        defer { cleanup(directory) }
        let url = directory.appendingPathComponent("doc.md")

        let panel = FakeFilePanelProvider()
        panel.nextSaveURL = url

        let model = WorkspaceModel(stateStore: FakeStateStore(), panel: panel)
        await model.newDocument()
        model.activeDocument = model.activeDocument?.updatingText("dirty")
        model.requestCloseDocument()

        await model.resolveClose(.save)

        #expect(model.activeDocument == nil)
        #expect(model.pendingClose == false)
        let (text, _) = try FileStore().read(from: url)
        #expect(text == "dirty")
    }

    @Test func closePromptSaveCancelledKeepsDocument() async {
        let panel = FakeFilePanelProvider()
        let model = WorkspaceModel(stateStore: FakeStateStore(), panel: panel)
        await model.newDocument()
        model.activeDocument = model.activeDocument?.updatingText("dirty")
        model.requestCloseDocument()

        await model.resolveClose(.save)

        #expect(model.activeDocument != nil)
        #expect(model.activeDocument?.state == .dirty)
        #expect(model.pendingClose == false)
    }

    // MARK: - Open folder

    @Test func openFolderRecordsURL() async {
        let directory = temporaryDirectory()
        defer { cleanup(directory) }

        let panel = FakeFilePanelProvider()
        panel.nextFolderURL = directory

        let model = WorkspaceModel(stateStore: FakeStateStore(), panel: panel)
        await model.openFolder()

        #expect(model.folderURL == directory)
        #expect(model.activeDocument == nil)
    }

    // MARK: - State store

    @Test func modelReadsSidebarVisibilityFromStore() {
        let store = FakeStateStore()
        store.sidebarVisible = false
        let model = WorkspaceModel(stateStore: store)
        #expect(model.sidebarVisible == false)
    }

    @Test func modelWritesSidebarVisibilityToStore() {
        let store = FakeStateStore()
        let model = WorkspaceModel(stateStore: store)
        model.sidebarVisible = false
        #expect(store.sidebarVisible == false)
    }

    @Test func modelReadsSectionExpansionFromStore() {
        let store = FakeStateStore()
        store.sidebarSectionExpanded = ["folder": false, "outline": true]
        let model = WorkspaceModel(stateStore: store)
        #expect(model.isSectionExpanded(.folder) == false)
        #expect(model.isSectionExpanded(.outline) == true)
    }

    @Test func modelWritesSectionExpansionToStore() {
        let store = FakeStateStore()
        let model = WorkspaceModel(stateStore: store)
        model.setSectionExpanded(.folder, false)
        #expect(store.sidebarSectionExpanded["folder"] == false)
    }
}
