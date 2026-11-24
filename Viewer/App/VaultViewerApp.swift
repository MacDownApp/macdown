import SwiftUI
import ViewerCore

@main
struct VaultViewerApp: App {
    @StateObject private var store = VaultStore()
    @StateObject private var themes = ThemeStore()
    @StateObject private var fonts = FontStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(themes)
                .environmentObject(fonts)
                .onOpenURL { store.handle(url: $0) }
                .onChange(of: scenePhase) { phase in
                    // iCloud may have changed notes while the app was in the background.
                    if phase == .active { store.refresh() }
                }
        }
    }
}
