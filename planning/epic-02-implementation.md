# EPIC-02 Implementation Plan — Workspace Shell

> **Issue:** [#3 — [EPIC-02] Workspace shell: WindowGroup, NavigationSplitView, commands](https://github.com/Joncallim/macdown_2/issues/3)
> **Branch:** `epic/02-workspace-shell` → PR into `rewrite/main`
> **Depends on:** E01 (merged, `75c9083`). Uses `FileDocument`, `FileStore`, `FileFormatRegistry` from `FileCore`.
> **Result:** a real app shell — NavigationSplitView with collapsible sidebar, placeholder sections, content area driven by FileCore, full File menu command set, sidebar toggle (toolbar + ⌃⌘S), window/sidebar state restoration, About panel.

---

## 1. Ground rules (binding, carried from E00)

1. macOS 26.0 deployment target. No availability checks.
2. Swift 6 + strict concurrency. Zero warnings.
3. SPM only. No new third-party dependencies this epic.
4. Do not touch the legacy tree.
5. `@Observable` (Observation framework), not Combine/`ObservableObject`.
6. `WorkspaceModel` is `@MainActor` and lives in the SPM `Workspace` module; SwiftUI scene wiring lives in the app target. **No AppKit imports in `WorkspaceModel` itself** — platform panels are abstracted behind a protocol.
7. Stock SwiftUI containers only. **No custom backgrounds behind toolbars or the sidebar** — Liquid Glass polish is E15.
8. Tabs are E03: this epic has exactly one content slot (`activeDocument`). Do not build tab UI, tab bar, or multi-document state.
9. Tests use Swift Testing (`@Test`). App-target UI code is not unit-tested; `WorkspaceModel` command state is.

---

## 2. Architecture

### 2.1 Module boundaries

```
┌────────────────────────────── App target (MacDown2/MacDown2/) ──────────────────────────────┐
│ MacDown2App            @main, WindowGroup, .commands                                        │
│ WorkspaceCommands      SwiftUI Commands: File menu set, View menu sidebar toggle            │
│ WorkspaceShellView     NavigationSplitView (sidebar / content [+ optional inspector])       │
│ SidebarView            Placeholder "Folder" + "Outline" sections (DisclosureGroup)          │
│ ContentAreaView        Empty state OR read-only document placeholder                        │
│ InspectorView          Placeholder, collapsed by default                                    │
│ NSFilePanelProvider    NSOpenPanel/NSSavePanel impl of FilePanelProviding (AppKit)          │
└──────────────────────────────────────┬──────────────────────────────────────────────────────┘
                                       │ imports Workspace
┌──────────────────────── SPM Workspace module (MacDown2/Packages/MacDownKit/Sources/Workspace/) ┐
│ WorkspaceModel        @MainActor @Observable — shell state + command routing                 │
│ FilePanelProviding    protocol (open file / open folder / save panel)                        │
│ WorkspaceStateStoring protocol + WorkspaceStateStore (UserDefaults-backed)                   │
│ WorkspaceError        public error enum                                                      │
│ Workspace.swift       module marker (keep, extend doc comment)                               │
└──────────────────────────────────────┬──────────────────────────────────────────────────────┘
                                       │ imports FileCore (E01)
                          FileDocument / FileStore / FileFormatRegistry
```

**Why this split:** `WorkspaceModel` must be unit-testable without a window, a menu, or AppKit. Everything testable lives in the package; everything that renders or shows panels lives in the app target. `AppSettings` (E13) is *not* involved — sidebar visibility is window state, stored by `Workspace`, not user preferences.

### 2.2 Public API contract (Workspace module)

```swift
// FilePanelProviding.swift
/// Platform file panels, abstracted so WorkspaceModel is testable.
public protocol FilePanelProviding: Sendable {
    /// One existing file, filtered to FileFormatRegistry UTTypes. nil = cancelled.
    func chooseFile() async -> URL?
    /// One existing directory. nil = cancelled.
    func chooseFolder() async -> URL?
    /// Save destination for an untitled document. nil = cancelled.
    func chooseSaveLocation(defaultName: String, format: FileFormat) async -> URL?
}

// WorkspaceStateStoring.swift
public protocol WorkspaceStateStoring: Sendable {
    var sidebarVisible: Bool { get set }
    var sidebarSectionExpanded: [String: Bool] { get set }   // keyed: "folder", "outline"
}
/// UserDefaults-backed; suite name "com.joncallim.macdown2.workspace".
public struct WorkspaceStateStore: WorkspaceStateStoring { … }

// WorkspaceError.swift
public enum WorkspaceError: Error {
    case openFailed(underlying: FileStoreError)
    case saveFailed(underlying: FileStoreError)
    case noActiveDocument
}

// WorkspaceModel.swift
@MainActor @Observable
public final class WorkspaceModel {
    // MARK: State
    public private(set) var activeDocument: FileDocument?
    public private(set) var folderURL: URL?
    public private(set) var lastError: WorkspaceError?
    /// Non-nil while a dirty-close prompt should be shown by the view.
    public private(set) var pendingClose: Bool
    public var sidebarVisible: Bool { get set }            // persisted via stateStore
    public func isSectionExpanded(_ key: SidebarSection) -> Bool
    public func setSectionExpanded(_ key: SidebarSection, _ expanded: Bool)

    // MARK: Init
    public init(stateStore: WorkspaceStateStoring = WorkspaceStateStore(),
                panel: (any FilePanelProviding)? = nil)

    // MARK: Intents (called by menu commands; panel injected at app level)
    public func newDocument()
    public func openFile() async                 // shows panel, loads via FileCore
    public func openFolder() async               // shows panel, records folderURL
    public func save() async                     // save; if untitled → save-panel flow
    public func saveAs() async
    public func requestCloseDocument()           // clean → closes; dirty → pendingClose = true
    public func resolveClose(_ resolution: CloseResolution) async  // from the alert

    // MARK: Command enablement (unit-tested)
    public var canSave: Bool { get }             // doc exists && (dirty || untitled-with-content)
    public var canClose: Bool { get }            // activeDocument != nil
    public var hasActiveDocument: Bool { get }
}

public enum SidebarSection: String, Sendable { case folder, outline }
```

Behavioral notes the implementer must honor:

- `openFile()` while a dirty document is active runs the same dirty flow as `requestCloseDocument` first; cancel aborts the open.
- `save()` on an untitled document = `saveAs()` (panel first). A user cancelling the save panel leaves the document open and dirty — **never** silently discards.
- `resolveClose(.save)` re-enters `save()`; if that save is cancelled/fails, the close is aborted (`pendingClose = false`, document stays open).
- After a successful `saveAs`, call `activeDocument.clearRecovery()` (E01) so the untitled recovery buffer does not resurrect the doc on next launch.
- New untitled documents get `FileDocument()` (defaults to Markdown format).

### 2.3 App-target view tree

```
WindowGroup {
    WorkspaceShellView(model: workspaceModel)          // owns NavigationSplitView
      ├─ sidebar:   SidebarView(model:)                // DisclosureGroup "Folder" (folderURL name or "No Folder Opened")
      │                                                // DisclosureGroup "Outline" (static placeholder rows)
      ├─ content:   ContentAreaView(model:)            // if doc: name + format + ScrollView{Text(doc.text)} monospaced, read-only
      │                                                // else: empty-state ("No Document", "Open a file with ⌘O")
      └─ inspector: InspectorView()                    // placeholder text; column hidden by default
}
.toolbar { ToolbarItem(placement: .primaryAction) sidebar toggle button }   // or .navigation on macOS — verify visually
.alert("Unsaved Changes", isPresented: pendingClose) { Save / Discard / Cancel }
```

- Sidebar toggle must **not** use the private `NSSplitViewController.toggleSidebar` selector hack. Bind `NavigationSplitView(columnVisibility:)` to `model.sidebarVisible` (map `NavigationSplitViewVisibility` ⇄ `Bool`; hiding = `.detailOnly`, showing = `.doubleColumn`). One source of truth, persisted.
- Inspector column: use `NavigationSplitView` 3-column init but default it off via `navigationSplitViewColumnWidth`/visibility binding or simply omit the inspector param — **decision: include the 3-column form with inspector visibility bound to a persisted Bool, default false.** If SwiftUI on 26 makes this awkward, drop to 2-column and note it on the PR; inspector is explicitly "optional" in the epic.
- `ContentAreaView` read-only text: `ScrollView { Text(document.text).font(.system(.body, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).padding() }`. Editing is E04.

### 2.4 Commands & menu placement

SwiftUI `Commands` attached to the `WindowGroup` scene, routed with `@FocusedValue(\.workspaceModel)`:

| Command | Shortcut | Menu placement | Enabled when |
|---|---|---|---|
| New File | ⌘N | `CommandGroup(replacing: .newItem)` | always |
| Open… | ⌘O | same group | always |
| Open Folder… | ⌘⇧O | same group | always |
| Save | ⌘S | `CommandGroup(replacing: .saveItem)` | `model.canSave` |
| Save As… | ⌘⇧S | same group | `model.hasActiveDocument` |
| Close Tab | ⌘W | same group (label "Close Tab" per epic) | `model.canClose` |
| Toggle Sidebar | ⌃⌘S | `CommandGroup(before: .sidebar)` | always |

- Wire focus: define `extension FocusedValues { var workspaceModel: WorkspaceModel? }` and set `.focusedSceneValue(\.workspaceModel, model)` on the shell view. Commands struct reads `@FocusedValue(\.workspaceModel) private var model`.
- All command bodies call the async intents via `Task { await model.… }`.
- **About:** leave the default About menu item. Verify the panel shows "MacDown 2" (it reads `CFBundleDisplayName` / `CFBundleName` from the generated Info.plist — already correct). If it does not, add `CommandGroup(replacing: .appInfo)` calling `NSApp.orderFrontStandardAboutPanel(options:)`. Do not build a custom About window in this epic.

### 2.5 Persistence & restoration

- Window frame: automatic AppKit restoration via `WindowGroup`. Do not set an explicit frame after first launch. Set `.defaultSize(width: 1200, height: 800)` on the scene content only.
- Sidebar visibility + section expansion: `WorkspaceStateStore` (UserDefaults, suite `com.joncallim.macdown2.workspace`). `WorkspaceModel` loads on init, writes on change (Observation makes this trivial: didSet on the computed properties).
- Session/tab restore is E03 — out of scope. Do not write tab state anywhere.

---

## 3. File layout (exact)

New / changed in the package:

```
MacDown2/Packages/MacDownKit/Sources/Workspace/
    Workspace.swift                 # extend doc comment, keep moduleName
    WorkspaceModel.swift            # new
    FilePanelProviding.swift        # new
    WorkspaceStateStore.swift       # new (protocol + UserDefaults impl)
    WorkspaceError.swift            # new
MacDown2/Packages/MacDownKit/Tests/WorkspaceTests/
    WorkspaceModelTests.swift       # new (replaces/extends stub; keep moduleLoads)
    WorkspaceStateStoreTests.swift  # new
    Fakes.swift                     # FakePanel, FakeStateStore
```

New / changed in the app target:

```
MacDown2/MacDown2/
    MacDown2App.swift               # WindowGroup + .commands + defaultSize
    ContentView.swift               # DELETED (superseded by WorkspaceShellView)
    WorkspaceShellView.swift        # new
    SidebarView.swift               # new
    ContentAreaView.swift           # new
    InspectorView.swift             # new
    WorkspaceCommands.swift         # new (Commands value + FocusedValues key)
    NSFilePanelProvider.swift       # new (AppKit impl of FilePanelProviding)
```

`Package.swift`: **no changes** (Workspace already depends on FileCore).
`project.yml`: **no changes** (app target already links Workspace).

---

## 4. Test plan (Workspace module, Swift Testing)

Fakes: `FakePanel` (scripted URL responses), `FakeStateStore` (in-memory dictionary).

1. `newDocument` → untitled doc active, `canSave == false` until text changes, `canClose == true`.
2. `openFile()` with scripted panel URL (temp .md on disk) → doc loaded, `state == .clean`, format = markdown, `canSave == false`.
3. `openFile()` while dirty → fake prompts… (drive via `requestCloseDocument` + `resolveClose` in sequence): cancel keeps old doc and never calls the panel.
4. `save()` untitled with fake panel URL → file written via FileStore, `state == .clean`, `canSave == false`.
5. `save()` with panel returning nil (cancel) → doc stays open, dirty, no error thrown.
6. `save()` on existing file → overwrites (verify via FileStore read), no panel shown.
7. `requestCloseDocument()` on clean doc → closes immediately, `activeDocument == nil`, `pendingClose == false`.
8. `requestCloseDocument()` on dirty doc → `pendingClose == true`, doc retained.
9. `resolveClose(.cancel)` → `pendingClose == false`, doc still dirty & active.
10. `resolveClose(.discard)` → doc closed, `activeDocument == nil`.
11. `resolveClose(.save)` (existing file) → saved & closed; `resolveClose(.save)` on untitled with cancelled panel → close aborted, doc open.
12. `openFolder()` → `folderURL` recorded; no document created.
13. Command enablement matrix: nil doc / clean / dirty / untitled-empty / untitled-content × `canSave` / `canClose`.
14. `WorkspaceStateStore` round-trip via a unique UserDefaults suite; `FakeStateStore` used everywhere else.
15. Errors: `save()` with read-only directory → `lastError == .saveFailed`, doc still open & dirty.

Keep `moduleLoads()` from the E00 stub.

---

## 5. Implementation order

1. `WorkspaceStateStore.swift` + `WorkspaceStateStoreTests` → run `swift test`.
2. `FilePanelProviding.swift` (+ `Fakes.swift`) → compiles.
3. `WorkspaceError.swift` → compiles.
4. `WorkspaceModel.swift` + `WorkspaceModelTests` → all §4 tests green (`cd MacDown2/Packages/MacDownKit && swift test`).
5. App: `NSFilePanelProvider.swift` (NSOpenPanel/NSSavePanel, `beginSheetModal`-style wrapped in `withCheckedContinuation`, or the modal-less presentation; pick one and keep it simple).
6. App: `WorkspaceShellView` + `SidebarView` + `ContentAreaView` + `InspectorView`; delete `ContentView.swift`; update `MacDown2App.swift`.
7. App: `WorkspaceCommands.swift` + FocusedValues wiring + toolbar sidebar toggle + dirty-close `.alert`.
8. Validate (§6), then manual acceptance pass (§7), then PR.

---

## 6. Validation (must all pass before PR review)

```bash
cd MacDown2/Packages/MacDownKit && swift build && swift test   # all green incl. §4
cd ../../..                                                     # repo root
swiftformat --lint MacDown2                                     # clean
swiftlint lint --strict MacDown2                                # clean
cd MacDown2 && xcodegen generate
xcodebuild -project MacDown2.xcodeproj -scheme MacDown2  -destination 'platform=macOS' build
xcodebuild -project MacDown2.xcodeproj -scheme macdown2  -destination 'platform=macOS' build
```

## 7. Manual acceptance pass (map to issue #3 checkboxes)

| #3 checkbox | How to verify |
|---|---|
| Launch → empty workspace; ⌘O opens file into content area via FileCore | Run app, empty state visible; ⌘O pick a .md; name/format/text shown |
| Sidebar collapses/expands from toolbar + keyboard; persists across relaunch | Toolbar button + ⌃⌘S both toggle; quit, relaunch → same visibility |
| All listed menu items exist with correct shortcuts and enable/disable | File menu: six items, shortcuts per §2.4; Save disabled for clean saved doc |
| Window frame + sidebar state restored on relaunch | Resize/move window, quit, relaunch → restored |

## 8. Handoff notes / known pitfalls

- **Do not** implement tabs, a tab bar, `TabStore`, or session restore of documents — that is E03 and reviewers will reject scope creep.
- `NavigationSplitViewVisibility` ⇄ `Bool` mapping: hide = `.detailOnly`; anything else = visible. Do not persist the enum's raw value.
- `@FocusedValue` (not `@FocusedObject`) — `WorkspaceModel` is `@Observable`, not `ObservableObject`.
- The `.alert` for dirty close must be driven by `model.pendingClose` with buttons calling `resolveClose`; do not use `NSAlert` — keep it SwiftUI.
- `NSFilePanelProvider` runs on the main actor implicitly (panels); mark it `@MainActor` and satisfy the `Sendable` protocol requirement carefully — a `@MainActor` class can conform if the protocol methods are awaited from main. If strict concurrency complains, make the protocol non-`Sendable` and note why.
- UserDefaults suite for tests: create per-test suite names (`UUID().uuidString`) and remove them in teardown; never touch the real app suite in tests.
- If `NavigationSplitView` 3-column inspector feels unstable on macOS 26, ship 2-column and comment on the PR — the epic marks the inspector optional.
- App icon/dock icon: untouched (E15/E17).
