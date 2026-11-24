import SwiftUI
import UniformTypeIdentifiers
import ViewerCore

struct ContentView: View {
    @EnvironmentObject private var store: VaultStore
    @EnvironmentObject private var themes: ThemeStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showFolderPicker = false
    @State private var search = ""
    @State private var visibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            SidebarView(search: $search, chooseFolder: { showFolderPicker = true })
                .navigationTitle(store.vaultName ?? "Vault")
        } detail: {
            NoteScreen()
        }
        .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
            if case let .success(url) = result { store.chooseVault(url) }
        }
        // A fixed dark or light theme also sets the app's own colors, so the sidebar matches.
        .preferredColorScheme(forcedScheme)
    }

    private var forcedScheme: ColorScheme? {
        guard let theme = themes.current, !theme.followsSystem else { return nil }
        return theme.isDark(systemDark: false) ? .dark : .light
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject private var store: VaultStore
    @Binding var search: String
    let chooseFolder: () -> Void

    var body: some View {
        Group {
            if store.vaultName == nil {
                EmptyVault(chooseFolder: chooseFolder)
            } else if search.trimmingCharacters(in: .whitespaces).isEmpty {
                List(store.tree, children: \.children, selection: selection) { node in
                    Label(node.name, systemImage: node.kind == .folder ? "folder" : (node.kind == .pdf ? "doc.richtext" : "doc.text"))
                }
            } else {
                List(store.search(search), id: \.self, selection: selection) { path in
                    VStack(alignment: .leading, spacing: 2) {
                        Text((path as NSString).pathExtension.lowercased() == "pdf"
                             ? (path as NSString).lastPathComponent
                             : ((path as NSString).lastPathComponent as NSString).deletingPathExtension)
                        let folder = (path as NSString).deletingLastPathComponent
                        if !folder.isEmpty { Text(folder).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search notes")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if store.isLoading { ProgressView() }
                Menu {
                    Button { chooseFolder() } label: { Label("Choose Vault Folder…", systemImage: "folder.badge.plus") }
                    Button { store.refresh() } label: { Label("Reload Vault", systemImage: "arrow.clockwise") }
                        .disabled(store.vaultName == nil)
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }

    /// Selecting a folder row only opens and closes it; only notes and PDFs open.
    private var selection: Binding<String?> {
        Binding(get: { store.selectedPath },
                set: { if let path = $0, store.isOpenable(path) { store.open(path) } })
    }
}

struct EmptyVault: View {
    let chooseFolder: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark").font(.system(size: 44)).foregroundStyle(.secondary)
            Text("Choose your Obsidian vault").font(.headline)
            Text("Pick the vault folder in iCloud Drive. Notes open read-only.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Choose Folder…", action: chooseFolder).buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}

// MARK: - Note

struct NoteScreen: View {
    @EnvironmentObject private var store: VaultStore
    @EnvironmentObject private var themes: ThemeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let systemDark = colorScheme == .dark
        let theme = themes.current
        ZStack {
            Color(hex: theme?.backgroundHex(systemDark: systemDark) ?? "#ffffff").ignoresSafeArea()
            if let item = store.pdf {
                PDFScreen(item: item)
            } else if let note = store.note, let path = store.selectedPath {
                NoteWebView(
                    html: ViewerPage.html(note: note, title: store.noteTitle,
                                          themeCSS: theme?.css(systemDark: systemDark) ?? "",
                                          scrollTo: store.scrollTarget),
                    baseURL: baseURL(for: path),
                    currentPath: path,
                    zoom: themes.textScale,
                    background: UIColor(Color(hex: theme?.backgroundHex(systemDark: systemDark) ?? "#ffffff")),
                    store: store)
                .ignoresSafeArea(edges: .bottom)
            } else if let message = store.message {
                Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(32)
            } else if store.isLoading {
                ProgressView()
            } else {
                Text(store.vaultName == nil ? "" : "Select a note").foregroundStyle(.secondary)
            }
        }
        .navigationTitle(store.noteTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if store.pdf == nil {
                    Button { themes.adjustScale(by: -0.1) } label: { Image(systemName: "textformat.size.smaller") }
                    Button { themes.adjustScale(by: 0.1) } label: { Image(systemName: "textformat.size.larger") }
                    Menu {
                        Picker("Theme", selection: Binding(get: { themes.themeName }, set: { themes.themeName = $0 })) {
                            ForEach(themes.themes) { Text($0.name).tag($0.name) }
                        }
                    } label: { Image(systemName: "paintpalette") }
                }
            }
        }
    }

    /// Relative links in the note resolve against the note's own folder.
    private func baseURL(for path: String) -> URL {
        let folder = (path as NSString).deletingLastPathComponent
        let encoded = folder.isEmpty ? "" : (folder.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? folder) + "/"
        return URL(string: "md://vault/" + encoded) ?? URL(string: "md://vault/")!
    }
}

extension Color {
    /// `#rrggbb` (anything else gives white).
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0xFFFFFF
        if digits.count == 6 { Scanner(string: digits).scanHexInt64(&value) }
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}
