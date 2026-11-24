import SwiftUI
import UniformTypeIdentifiers
import ViewerCore

struct ContentView: View {
    @EnvironmentObject private var store: VaultStore
    @EnvironmentObject private var themes: ThemeStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showFolderPicker = false
    @State private var showSettings = false
    @State private var search = ""
    @State private var visibility = NavigationSplitViewVisibility.all
    @State private var stackPath: [String] = []

    var body: some View {
        Group {
            if sizeClass == .compact { compact } else { split }
        }
        .fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder]) { result in
            if case let .success(url) = result { store.chooseVault(url) }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .tint(themes.accentColor)
        .onChange(of: themes.accentHex) { _ in store.republishWidgets() }
        // A fixed dark or light theme also sets the app's own colors, so the sidebar matches.
        .preferredColorScheme(forcedScheme)
        // A note opened from outside (a widget) also shows in the phone layout.
        .onChange(of: store.selectedPath) { path in
            if sizeClass == .compact, let path = path, stackPath != [path] { stackPath = [path] }
        }
    }

    /// iPad: the sidebar and the note side by side.
    private var split: some View {
        NavigationSplitView(columnVisibility: $visibility) {
            sidebar(onOpen: { store.open($0) })
        } detail: {
            NoteScreen(showSettings: $showSettings)
        }
    }

    /// iPhone: the list first, a note pushed on top of it.
    private var compact: some View {
        NavigationStack(path: $stackPath) {
            sidebar(onOpen: { path in store.open(path); stackPath = [path] })
                .navigationDestination(for: String.self) { _ in NoteScreen(showSettings: $showSettings) }
        }
    }

    private func sidebar(onOpen: @escaping (String) -> Void) -> some View {
        SidebarView(search: $search, chooseFolder: { showFolderPicker = true }, showSettings: { showSettings = true }, onOpen: onOpen)
            .navigationTitle(store.vaultName ?? "Vault")
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
    let showSettings: () -> Void
    let onOpen: (String) -> Void

    private static let expandedKey = "expandedFolders"
    @State private var expanded: Set<String> = Set(UserDefaults.standard.stringArray(forKey: SidebarView.expandedKey) ?? [])

    var body: some View {
        Group {
            if store.vaultName == nil {
                EmptyVault(chooseFolder: chooseFolder)
            } else if search.trimmingCharacters(in: .whitespaces).isEmpty {
                List {
                    ForEach(VaultOutline.rows(tree: store.tree, expanded: expanded)) { row in
                        treeRow(row)
                    }
                }
                .listStyle(.sidebar)
            } else {
                List(store.search(search), id: \.self) { path in
                    Button { onOpen(path) } label: { searchLabel(path) }
                        .buttonStyle(.plain)
                        .listRowBackground(rowBackground(selected: store.selectedPath == path))
                }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search notes")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if store.isLoading { ProgressView() }
                Button(action: showSettings) { Image(systemName: "textformat") }
                Menu {
                    Button { chooseFolder() } label: { Label("Choose Vault Folder…", systemImage: "folder.badge.plus") }
                    Button { store.refresh() } label: { Label("Reload Vault", systemImage: "arrow.clockwise") }
                        .disabled(store.vaultName == nil)
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .onChange(of: expanded) { UserDefaults.standard.set(Array($0), forKey: SidebarView.expandedKey) }
        .onChange(of: store.tree) { tree in expanded = VaultOutline.pruned(expanded, tree: tree) }
        // Opening a note (also from a widget) opens the folders above it, so it is visible in the list.
        .onChange(of: store.selectedPath) { path in
            if let path = path { expanded.formUnion(VaultOutline.ancestors(of: path)) }
        }
    }

    /// One row. The whole row of a folder opens and closes it, not only the arrow.
    private func treeRow(_ row: VaultOutline.Row) -> some View {
        let node = row.node
        let isOpen = expanded.contains(node.id)
        return Button {
            if node.isFolder {
                withAnimation(.easeInOut(duration: 0.15)) { expanded = VaultOutline.toggled(node.id, in: expanded) }
            } else {
                onOpen(node.id)
            }
        } label: {
            HStack(spacing: 6) {
                Spacer().frame(width: CGFloat(row.depth) * 16)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .frame(width: 14).opacity(node.isFolder ? 1 : 0)
                Image(systemName: node.kind == .folder ? (isOpen ? "folder.fill" : "folder") : (node.kind == .pdf ? "doc.richtext" : "doc.text"))
                    .foregroundStyle(node.isFolder ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                Text(node.name).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(rowBackground(selected: !node.isFolder && store.selectedPath == node.id))
        .accessibilityLabel(node.isFolder ? "\(node.name), folder, \(isOpen ? "expanded" : "collapsed")" : node.name)
        .accessibilityAddTraits(.isButton)
    }

    /// The highlight of the open note: a rounded shape in the accent color, a little inside the row.
    private func rowBackground(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selected ? AnyShapeStyle(.tint.opacity(0.22)) : AnyShapeStyle(Color.clear))
            .padding(.vertical, 1)
            .padding(.horizontal, 6)
    }

    private func searchLabel(_ path: String) -> some View {
        let isPDF = (path as NSString).pathExtension.lowercased() == "pdf"
        let name = isPDF ? (path as NSString).lastPathComponent : ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let folder = (path as NSString).deletingLastPathComponent
        return VStack(alignment: .leading, spacing: 2) {
            Text(name)
            if !folder.isEmpty { Text(folder).font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
    @EnvironmentObject private var fonts: FontStore
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showSettings: Bool

    var body: some View {
        let systemDark = colorScheme == .dark
        let theme = themes.current
        let background = Color(hex: theme?.backgroundHex(systemDark: systemDark) ?? "#ffffff")
        ZStack {
            background.ignoresSafeArea()
            if let item = store.pdf {
                PDFScreen(item: item)
            } else if let note = store.note, let path = store.selectedPath {
                NoteWebView(
                    html: ViewerPage.html(note: note, title: store.noteTitle,
                                          themeCSS: theme?.css(systemDark: systemDark) ?? "",
                                          fontCSS: fonts.css,
                                          accentCSS: AccentCSS.css(hex: themes.accentHex),
                                          scrollTo: store.scrollTarget),
                    baseURL: baseURL(for: path),
                    currentPath: path,
                    zoom: themes.textScale,
                    background: UIColor(background),
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
                    Button { showSettings = true } label: { Image(systemName: "paintpalette") }
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
