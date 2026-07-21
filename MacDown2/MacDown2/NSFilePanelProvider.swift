import AppKit
import FileCore
import Foundation
import Workspace

/// AppKit implementation of `FilePanelProviding` for the MacDown 2 app target.
///
/// For this single-window app, panels are presented as sheets on the current key
/// window. If no key window is available, the panel falls back to a modal dialog.
@MainActor
final class NSFilePanelProvider: FilePanelProviding {
    private weak var window: NSWindow?

    init(window: NSWindow? = nil) {
        self.window = window
    }

    func chooseFile() async -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = FileFormatRegistry.defaultFormats.map(\.utType)

        return await present(panel)
    }

    func chooseFolder() async -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Open Folder"

        return await present(panel)
    }

    func chooseSaveLocation(defaultName: String, format: FileFormat) async -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [format.utType]
        panel.canCreateDirectories = true

        return await present(panel)
    }

    private func present(_ panel: NSOpenPanel) async -> URL? {
        await withCheckedContinuation { continuation in
            if let targetWindow = window ?? NSApp.keyWindow {
                panel.beginSheetModal(for: targetWindow) { result in
                    continuation.resume(returning: result == .OK ? panel.urls.first : nil)
                }
            } else {
                let result = panel.runModal()
                continuation.resume(returning: result == .OK ? panel.urls.first : nil)
            }
        }
    }

    private func present(_ panel: NSSavePanel) async -> URL? {
        await withCheckedContinuation { continuation in
            if let targetWindow = window ?? NSApp.keyWindow {
                panel.beginSheetModal(for: targetWindow) { result in
                    continuation.resume(returning: result == .OK ? panel.url : nil)
                }
            } else {
                let result = panel.runModal()
                continuation.resume(returning: result == .OK ? panel.url : nil)
            }
        }
    }
}
