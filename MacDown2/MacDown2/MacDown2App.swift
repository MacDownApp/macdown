import SwiftUI

@main
struct MacDown2App: App {
    var body: some Scene {
        WindowGroup {
            WorkspaceShellView()
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            WorkspaceCommands()
        }
    }
}

// MARK: - About panel

// The default About menu item reads CFBundleDisplayName from the generated
// Info.plist, which is set to "MacDown 2" in project.yml. No custom About
// window is required for EPIC-02.
