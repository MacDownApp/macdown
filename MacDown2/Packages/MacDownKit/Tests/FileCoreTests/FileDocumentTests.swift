@testable import FileCore
import Foundation
import Testing

@Test func documentStartsClean() {
    let document = FileDocument(text: "hello")
    #expect(document.state == .clean)
    #expect(document.text == "hello")
    #expect(document.fileURL == nil)
}

@Test func editingTextMarksDirty() {
    let document = FileDocument(text: "hello")
    let edited = document.updatingText("hello world")
    #expect(edited.state == .dirty)
    #expect(edited.text == "hello world")
}

@Test func unchangedTextKeepsClean() {
    let document = FileDocument(text: "hello")
    let same = document.updatingText("hello")
    #expect(same.state == .clean)
}

@Test func requestCloseOnCleanReturnsDiscard() {
    let document = FileDocument(text: "hello")
    let (updated, resolution) = document.requestClose()
    #expect(resolution == .discard)
    #expect(updated.state == .clean)
}

@Test func requestCloseOnDirtyPrompts() {
    let document = FileDocument(text: "hello")
        .updatingText("hello world")
    let (updated, resolution) = document.requestClose()
    #expect(resolution == nil)
    #expect(updated.state == .promptingClose)
}

@Test func resolveCloseSaveReturnsClean() {
    let document = FileDocument(text: "hello")
        .updatingText("hello world")
        .requestClose().document
    let resolved = document.resolveClose(.save)
    #expect(resolved.state == .clean)
}

@Test func resolveCloseCancelReturnsDirty() {
    let document = FileDocument(text: "hello")
        .updatingText("hello world")
        .requestClose().document
    let resolved = document.resolveClose(.cancel)
    #expect(resolved.state == .dirty)
}

@Test func resolveCloseCancelOnCleanDocumentStaysClean() {
    // Cancelling a close outside the prompt flow must not dirty a clean doc.
    let document = FileDocument(text: "hello")
    #expect(document.state == .clean)
    let resolved = document.resolveClose(.cancel)
    #expect(resolved.state == .clean)
}

@Test func saveExistingFileMarksClean() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent("doc.md")
    let document = FileDocument(fileURL: url, text: "content")
    let saved = try document.save()

    #expect(saved.state == .clean)

    let (read, _) = try FileStore().read(from: url)
    #expect(read == "content")
}

@Test func saveAsUpdatesURLAndIdentity() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent("saved.md")
    let document = FileDocument(text: "untitled content")
    let saved = try document.saveAs(url)

    #expect(saved.fileURL == url)
    #expect(saved.state == .clean)
}

@Test func detectExternalChangeAfterDiskModification() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent("doc.md")
    let document = try FileDocument(fileURL: url, text: "original").save()

    // Small sleep to ensure modification date changes.
    try await Task.sleep(nanoseconds: 10_000_000)
    try FileStore().write("modified externally", to: url)

    #expect(document.detectExternalChange() == true)
}

@Test func resolveConflictUseExternalReloads() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent("doc.md")
    try FileStore().write("external", to: url)

    let document = FileDocument(fileURL: url, text: "local")
    let resolved = try document.resolveConflict(.useExternal)

    #expect(resolved.text == "external")
    #expect(resolved.state == .clean)
}

@Test func recoveryBufferPersistsUntitledContent() async {
    let document = FileDocument(text: "recovered content")
    await document.autosave()

    let recovered = await document.loadRecovery()
    #expect(recovered == "recovered content")

    await document.clearRecovery()
    let cleared = await document.loadRecovery()
    #expect(cleared == nil)
}

@Test func autosaveDoesNothingForSavedFiles() async {
    let url = URL(fileURLWithPath: "/tmp/\(UUID().uuidString).md")
    let document = FileDocument(fileURL: url, text: "saved file content")
    await document.autosave()

    let recovered = await document.loadRecovery()
    #expect(recovered == nil)
}
