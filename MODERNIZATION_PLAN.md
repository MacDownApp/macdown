# MacDown Modernization Plan

Audience: Claude Code instances (and humans) executing the work phase by phase.
Goal: turn MacDown (Objective-C, WebView, Hoedown, macOS 10.8 target) into a modern, **fast, reliable, fully native-looking** macOS Markdown editor.

## 0. Product Principles (these override everything else in this file)

1. **Speed and reliability come first.** If a feature threatens the budgets in section 2, it is cut, deferred, or made lazy. No exceptions.
2. **Native macOS look.** Keep MacDown's current design language: toolbar, two-pane editor/preview split, standard preferences window, standard menus and shortcuts. Use system controls, system materials, system accent color, SF Symbols, and Light/Dark appearance. No custom-drawn chrome, no web-style UI, no redesign.
3. **Never lose user text.** Autosave, crash-safe writes, file versions, and conflict prompts are mandatory.
4. **Small surface area.** Configuration is plain YAML files in a config directory. There is no plug-in API and no scripting API (AppleScript `.sdef` is kept as is).
5. **Everything heavy is lazy and off the main thread.**
6. **Optional features cost nothing when off.** Git, lint, and spell check are toggles. When a toggle is off, its code does not start: no background queue, no file watcher, no index, no memory.
7. **Two interface styles, one code base.** *Classic* (MacDown's current design language) and *Modern* (the macOS 27 design, native). Both use system controls and both must meet the same budgets.

Explicitly out of scope: AI features, slides/presentation mode, slash commands, focus mode, typewriter mode, writing goals, spreadsheet paste, plug-in API.

## 1. Current State (verified)

| Area | Today | Problem |
|---|---|---|
| Language | Objective-C, ARC, no Swift | Hard to add modern features |
| Deployment target | macOS 10.8 | Blocks TextKit 2, async/await, modern AppKit |
| Preview | `WebView` (deprecated, private headers in `WebView+WebViewPrivateHeaders.h`) | Deprecated, unsafe |
| Markdown parser | Hoedown 3.0.7 (patched, unmaintained) | No full GFM, no AST |
| Editor highlighting | `peg-markdown-highlight` submodule, built with `make` | Markdown only; hard to build |
| Preview code highlighting | Prism (bundled JS) | JS cost on every render |
| Math | MathJax (bundled, large) | Slow, large |
| Diagrams | Old `mermaid.min.js` + `viz.js` in `Resources/Extensions` | Outdated, always loaded |
| Themes | `.style` (editor) + `.css` (preview), Mou-era | Two unrelated systems |
| Dependencies | CocoaPods with patched private spec repo, Sparkle 1.x | Legacy |
| CI | Travis CI, Xcode 10.1 | Dead |
| Core size | `MPDocument.m` 2017 lines, `MPRenderer.m` 704 lines | God-object |

Mermaid, MathJax and Prism already exist in legacy form. The work is to **upgrade, unify and make lazy**.

## 2. Performance and Reliability Budgets

These are acceptance tests, measured in CI with a benchmark corpus (small note, 100 KB, 1 MB, 5 MB Markdown files; a 5,000-file folder; a large Git repo).

| Metric | Budget |
|---|---|
| Cold launch to editable window | < 0.5 s (document), < 1 s (with workspace) |
| Keystroke to screen (editor) | < 16 ms at 1 MB file, never blocks on preview, Git, or highlighting |
| Preview update after typing stops | < 100 ms for normal documents; 1 MB document < 500 ms |
| Open 5,000-file folder | Sidebar visible < 200 ms; scan runs in background |
| Idle CPU | ~0 % (no timers, no polling; FSEvents only) |
| Memory | < 150 MB with one normal document and preview |
| Crash-free sessions | > 99.9 %; no data loss in autosave tests |

Rules that enforce these budgets:
- The main thread only does UI. Parsing, highlighting, Git, file scans, and export run on background queues/actors with cancellation.
- Every update is **debounced and cancellable**. A new keystroke cancels stale preview and highlight work.
- Highlight and render **incrementally** (visible range first, rest in background).
- Load JS libraries **lazily**: KaTeX only if the document has math; Mermaid only if it has a Mermaid block.
- Keep **one warm WKWebView** per window and update it by DOM patching (diff), not full page reloads.
- Run the benchmarks with **all optional features on** (Git, lint, spell check, ligatures, multi-cursor) and in **both interface styles**. The budgets must hold in the worst case.
- Add Instruments signposts and an XCTest `measure` benchmark target in Phase 1. A phase is not done if a budget regresses.

## 3. Features That Can Overwhelm Speed (and what to do)

| Feature | Why it is dangerous | Decision |
|---|---|---|
| Re-highlighting the whole file per keystroke | O(n) on the main thread | Tree-sitter incremental parse, edit ranges only; background for off-screen |
| Syntax highlighting of huge fenced code blocks in preview | Slow render | Cap: blocks over N lines (for example 2,000) render as plain text |
| Mermaid (large JS bundle, slow layout) | Seconds of CPU, large memory | Lazy-load; render after idle; cache SVG by block hash; timeout and show error |
| Math (KaTeX) | Many formulas = slow DOM work | Lazy-load; cache rendered output by formula hash; render visible first |
| WKWebView start-up and full reloads | Process start is slow; flicker | Warm webview, DOM patching, reuse process pool |
| Git status in sidebar for large repos | `git status` can take seconds | **Toggle** (on by default). When off, libgit2 and the repo watcher never start. When on: async, cached, FSEvents-triggered, cancelable; show nothing until ready; **per-file badges only, no full-tree scan on big repos** (size threshold) |
| Git diff gutter marks per keystroke | Diff on every change is costly | Compute diff on save and on idle (e.g. 500 ms), only for the open file |
| Git history, blame, merge-conflict UI | Large and slow, many edge cases | **Defer.** Ship status, diff, stage, commit, branch switch only. No blame, no graph |
| Sidebar folder scan | Large trees block UI | Lazy per-folder loading; background enumeration; ignore `.git`, `node_modules`, hidden dirs |
| Many fonts bundled or all system fonts listed at start | Memory and launch cost | Bundle at most 2 to 3 fonts; use system fonts by default; enumerate font list lazily in the picker |
| Font ligatures on huge files | CoreText shaping cost | **Checkbox, on by default.** Applies to the code font. Safety net: above a very large file size (for example 5 MB) the app pauses ligatures and shows a note in the status area; the checkbox itself does not change |
| Continuous spell/grammar check on big files | Main thread stalls | **Toggle.** Uses the system `NSTextView` background checker, ignores code and URLs. When off, the checker is not attached. Pauses above a size limit with a status note |
| Wiki links and backlinks index | Requires indexing the whole workspace | **Defer.** Not in v1 |
| Markdown lint warnings | Extra parse pass per edit | **Toggle, off by default.** Runs on the AST in the background, only on idle (not per key), cancelable. When off, no rules load |
| Vega-Lite charts | Large JS (Vega + Vega-Lite), slow layout, remote data loading is a security risk | **Keep, lazy.** Load only when a `vega-lite` block exists; render after idle; cache by spec hash; row and time limits; remote data URLs **off by default** |
| Graphviz (`viz.js`) | Large JS, slow | **Cut.** Remove `viz.js` |
| Multi-cursor editing | `NSTextView` has no native multi-caret, so edits and carets need custom code; IME, undo, and autocomplete are risky | **Keep.** Cost only when used (extra carets only after a gesture). Edits apply as one undo step. Heavy testing required |
| Modern interface style (translucent materials) | GPU cost, more compositing | Use system materials only (no custom blur). Respect "Reduce Transparency". Must meet the same budgets as Classic |
| DOCX / EPUB export | Large dependencies, edge cases | **Cut** from v1. Keep HTML, PDF, print, copy as rich text |
| Loading all themes at launch | Wasted startup time | Load only the active theme; list others by file name; parse on selection |
| Theme file watcher | Cheap but can cause reload storms | Watch only the active theme file and config dir; debounce 200 ms |
| Quick Open (⌘P) / command palette index | Index of 5,000 files | Build lazily on first open; incremental updates from FSEvents; fuzzy match off main thread |
| Image paste with resize/compress | Heavy work on paste | Copy original file only; no compression in v1 |
| Raw HTML sanitization | Cost on large documents | Sanitize in the Swift renderer once per render; cached by block |
| Spotlight importer / Quick Look plug-in | Separate processes, no UI cost | Keep (low risk), but build after v1.0 |
| Sparkle update check | Network at launch | Check in background, 10+ s after launch |

## 4. Target Architecture

```
App (AppKit-first; SwiftUI only for the Settings window and small panels)
├── Document layer   MarkdownDocument (NSDocument): autosave, versions, crash-safe writes
├── Editor           TextKit 2 NSTextView, tree-sitter highlight engine, editing commands,
│                    multi-cursor layer (extra carets + multi-range edits as one undo step)
├── Markdown core    swift-markdown (AST) -> HTML renderer with source map
├── Preview          WKWebView (warm, DOM-patched) + lazily loaded KaTeX / Mermaid / Vega-Lite
├── Lint (optional)  Rule engine on the AST; starts only if enabled
├── ChromeStyle      Classic | Modern: one switch that configures window, toolbar, sidebar
├── Theme system     ThemeManager + YAML themes (one theme drives editor + preview + sidebar)
├── Workspace        Folder model, NSOutlineView sidebar (markdown only), FSEvents watcher
├── Git (optional)   GitProvider (libgit2), minimal: status, diff, stage, commit, branches
├── Fonts            FontManager (system fonts, per-element fonts)
└── Settings         Typed Settings (UserDefaults) + YAML config directory
```

AppKit-first reasoning: `NSOutlineView` (source-list style), `NSToolbar`, `NSSplitView`, and `NSTextView` give the true macOS look, feel and speed. SwiftUI is allowed only where it does not affect scrolling or typing performance.

Protocol seams (define in Phase 1): `MarkdownRenderer`, `PreviewView`, `SyntaxHighlighter`, `ThemeProvider`, `GitProvider`.

## 5. Configuration Directory (YAML)

Location: `~/.config/macdown/`

```
~/.config/macdown/
├── config.yaml          # optional: default theme, fonts, preview width, git options
└── themes/
    ├── my-theme.yaml    # user color schemes (override built-ins by name)
    └── ...
```

Notes:
- Built-in themes are bundled in the app as the same YAML format. User files in `themes/` add to or override them.
- Parse with **Yams** (SPM). Parse errors show a non-blocking message and fall back to the previous valid theme; they never crash and never block launch.
- The app reads this directory directly, so the app **cannot use the App Sandbox**. Distribute as Developer ID + notarization + Sparkle (as today). Document this decision in `CLAUDE.md`.
- The config file is read once at launch and on change (FSEvents on the directory, debounced). The Settings window edits `config.yaml` through the same typed model, so both stay in sync.

`config.yaml` feature switches (defaults shown). The same switches appear as checkboxes in Settings > Features:
```yaml
interface: classic          # classic | modern   (modern needs macOS 27)
editor:
  ligatures: true           # checkbox, on by default
  spell-check: true         # toggle
  multi-cursor: true
git:
  enabled: true             # toggle; off = libgit2 and watcher never start
lint:
  enabled: false            # toggle; off by default
  rules: []                 # optional rule names to enable or disable
charts:
  vega-lite-remote-data: false   # allow data.url from http(s)
```

Theme schema (sketch):
```yaml
name: Solarized Light
appearance: light            # light | dark | both (then provide `light:` and `dark:` blocks)
editor:
  background: "#fdf6e3"
  text: "#657b83"
  caret: "#586e75"
  selection: "#eee8d5"
  line-highlight: "#f5efdc"
tokens:                      # shared by editor and preview
  heading:       { color: "#268bd2", weight: bold }
  emphasis:      { italic: true }
  link:          { color: "#2aa198" }
  code:          { color: "#859900" }
  keyword:       { color: "#cb4b16" }
  string:        { color: "#2aa198" }
  comment:       { color: "#93a1a1", italic: true }
preview:
  background: "#fdf6e3"
  text: "#586e75"
  content-width: 760
  extra-css: ""              # optional path to a CSS file in the config dir
```

## 6. Phases

### Phase 0 – Revive the build (1 week)
- Get a clean build on current Xcode (universal binary: Apple Silicon + Intel).
- Raise deployment target to **macOS 13**. Build with the **macOS 27 SDK** and guard every macOS 27 API with `#available`, so Modern style is optional and older systems run Classic. Record in `CLAUDE.md`.
- Replace CocoaPods with **Swift Package Manager** (Sparkle 2, ArgumentParser, Yams). Temporarily vendor `hoedown` until Phase 2. Remove `Podfile`, `Gemfile`, patched spec repo.
- Keep `peg-markdown-highlight` building until Phase 3.
- Replace Travis with GitHub Actions (build + test).
- Add Swift and a bridging header.
- Exit: CI green; app launches, edits and previews as before.

### Phase 1 – Decompose, seams, benchmarks (1–2 weeks)
- Split `MPDocument` (export, scroll sync, file I/O, toolbar, preview coordination).
- Introduce protocol seams. Wrap Hoedown and WebView behind them.
- Snapshot tests: Markdown to HTML on a corpus (CommonMark spec, GFM spec, MacDown samples).
- Add the **benchmark target and signposts** (section 2) and record the baseline numbers of the current app.
- Exit: behavior unchanged; `MPDocument` under ~600 lines; baseline numbers committed.

### Phase 2 – Markdown core (2 weeks)
- Replace Hoedown with **swift-markdown** (cmark-gfm underneath). Gives an AST used by source maps, outline and scroll sync.
- Support: tables, task lists, strikethrough, autolinks, footnotes, front matter (YAML), heading anchors, alert boxes (`> [!NOTE]`), `[TOC]`.
- Custom hooks for math and Mermaid fences.
- Remove Hoedown, `hoedown_html_patch.c`, LibYAML.
- Exit: spec tests pass; render time within budget.

### Phase 3 – Native editor and highlighting (3 weeks)
- **TextKit 2** `NSTextView` subclass.
- **tree-sitter** highlighting (incremental): `tree-sitter-markdown` plus injected grammars for fenced code. First-wave languages: Swift, Objective-C, C, C++, Python, JavaScript, TypeScript, JSON, YAML, TOML, Shell, HTML, CSS, SQL, Go, Rust, Java, Ruby, PHP, Diff, LaTeX. Others load on demand; unknown languages are plain text.
- Same grammars generate preview code highlighting in Swift (`<span class="tok-…">`); Prism removed.
- Editing: list continuation, auto-pairing, indent handling, find/replace with regex (system find bar), word count in status area.
- **Multi-cursor:** add caret with ⌥-click, add next match with ⌘D, select all matches, column selection with ⌥-drag, Esc to return to one caret. Use `NSTextView` multiple `selectedRanges` for selection and `shouldChangeText(inRanges:replacementStrings:)` for edits; draw extra carets in a lightweight overlay. All edits from one keystroke form **one undo group**. Must work with IME composition, auto-pairing, and list continuation (these may fall back to simple behavior with multiple carets). Include fuzz tests that compare multi-cursor edits with repeated single-cursor edits.
- **Spell check toggle:** attach the system checker only when enabled; skip code spans, code blocks, URLs, and front matter.
- Remove `peg-markdown-highlight`, `Dependency/` submodule, `syntax_highlighting.json`.
- Exit: 1 MB file typing stays under 16 ms; highlight is incremental.

### Phase 4 – WKWebView preview (2 weeks)
- Replace `WebView`; delete private headers.
- Custom URL scheme handler for local assets (images, relative links).
- JS bridge: scroll position, link clicks, task-list checkbox toggles (edit source), render-complete events.
- DOM patching for updates; warm webview; scroll sync from AST source positions.
- Export: HTML, PDF (`createPDF`), print, copy as rich text.
- Content Security Policy; raw HTML sanitized by default (setting to allow).
- Exit: no deprecated `WebView` symbols; preview budget met.

### Phase 5 – LaTeX (1 week)
- **KaTeX** bundled, lazy-loaded, offline. Syntax: `$inline$`, `$$block$$`, ```` ```math ````. Currency (`$5`) and escapes handled in the Swift parser.
- Cache output per formula. Highlight LaTeX in the editor via tree-sitter.
- Remove MathJax.

### Phase 6 – Mermaid and Vega-Lite (2 weeks)
- Current **Mermaid** bundled, lazy-loaded only when a Mermaid block exists. Render after idle; cache SVG by block hash; render timeout.
- Follows the active theme and appearance. Errors shown under the diagram.
- Remove `viz.js`.
- **Vega-Lite:** fenced ```` ```vega-lite ```` block with a JSON or YAML spec. Bundle Vega, Vega-Lite and Vega-Embed locally; lazy-load only when such a block exists. Render to SVG after idle, cache by spec hash, set a time limit and a data row limit, show errors under the block.
  - Data from local files (relative paths) goes through the asset scheme handler. Remote `data.url` is blocked unless `charts.vega-lite-remote-data` is true. Block `eval`-style expression features that the library allows to run unsafe code where possible, and keep the Content Security Policy on.
  - Colors and fonts come from the active theme (map theme tokens to the Vega `config`). SVG output is used for PDF export.

### Phase 7 – Theme system (2 weeks)
- YAML theme format (section 5). `ThemeManager` loads the active theme only; lists others by file name.
- Conversion script in `Tools/` for existing Mou `.style` and `Styles/*.css` themes.
- **Predefined themes (built in):** GitHub Light/Dark, Solarized Light/Dark, Tomorrow / Tomorrow Night, Nord, Dracula, One Light / One Dark, Gruvbox Light/Dark, Rosé Pine, Catppuccin Latte/Mocha, Paper, Writer, Mou Night, High Contrast.
- Theme chooser in Settings (standard pop-up menu/list, native controls). Follows system Light/Dark.
- Exit: switching theme updates editor, preview, diagrams and sidebar in < 100 ms, no restart.

### Phase 8 – Fonts (1 week)
- Separate fonts for editor body, editor code, preview body, preview headings, preview code. System fonts by default (SF Pro, SF Mono, New York).
- Use the **standard macOS font panel / pop-up menus**; font list loads lazily.
- Size, line height, content width. **Ligatures checkbox, on by default** (code font; also a preview code-font switch using CSS `font-ligatures`). See section 3 for the very-large-file safety net.
- Bundle at most 2 to 3 open-license fonts (for example Inter, JetBrains Mono); check licenses into `LICENSE/`.
- Optional user fonts folder `~/.config/macdown/fonts/`, exposed to the preview through the asset scheme.

### Phase 9 – Minimal sidebar (2 weeks)
- *File > Open Folder* opens a workspace. Single-file mode stays.
- `NSOutlineView` with the **source list** style (native look). Shows only `.md`, `.markdown` (and `.txt` by setting). Hides dotfiles, non-Markdown files, and folders with no Markdown inside (checked lazily, cached).
- Toggle with ⌘⌥S. Optional Outline tab (headings from the AST).
- Operations: new file, rename, move to Trash, reveal in Finder.
- FSEvents watcher; external changes update the list and open documents (conflict prompt).
- Quick Open (⌘P): lazy index, fuzzy match off the main thread.
- Exit: 5,000-file folder meets the budget.

### Phase 10 – Git, minimal, with on/off toggle (2 weeks)
- **Toggle** in Settings > Features (and `git.enabled`). Off means nothing Git related is created. Turning it on or off applies without restart.
- **libgit2** via a thin Swift wrapper; no dependency on system `git` for core features (shell out only for hooks/signing if needed).
- In order: (1) detect repo, show branch name; (2) sidebar status dots (async, cached, size-limited); (3) editor gutter marks vs `HEAD` (on save and idle); (4) diff of the current file, revert hunk; (5) stage, unstage, commit; (6) switch and create branch; (7) push/pull/fetch with Keychain credentials and SSH agent.
- **Not in v1:** history browser, blame, graph, merge-conflict UI.
- Confirmation sheet before any destructive action. All work off the main thread, cancellable.

### Phase 11 – Markdown lint, with on/off toggle (1 week)
- Off by default. Rules run on the swift-markdown AST in the background on idle, never per key, and are cancelable.
- Small rule set first: heading levels skip, duplicate headings, trailing spaces, inconsistent list markers, broken local links and images, missing alt text, bare URLs, line too long (optional).
- Warnings show as light underline marks in the editor and as a count in the status area. Click the count to jump between warnings. Each rule can be turned on or off in `config.yaml` and in Settings.
- Not included: wiki links and backlink checks (they need a workspace index).

### Phase 12 – Modern interface style (macOS 27) (2 weeks)
- Settings > General > **Interface: Classic / Modern** (`interface:` in `config.yaml`). Modern is available only on macOS 27 or later; on older systems the choice is hidden and Classic is used.
- Goal: Modern feels like a native macOS 27 app. This comes from using **standard system components built with the macOS 27 SDK** (window, toolbar, sidebar, split view, controls, materials, SF Symbols), not from custom drawing.
- First task is a **short spike**: read Apple's macOS 27 release notes and Human Interface Guidelines, and record the exact APIs for toolbar, sidebar, and materials in `docs/modern-style.md`. Do not guess API names; this plan does not assume details of the macOS 27 design.
- Implement `ChromeStyle` as the single switch that configures the window, toolbar, sidebar and split view for each style. Editor, preview and themes are shared, so there is one code base.
- Rules: honor "Reduce Transparency" and "Increase Contrast"; no custom blur; the theme system supplies content colors only, the system supplies chrome colors; switching style applies without restart.
- Exit: both styles meet all budgets in section 2; screenshot tests for both styles in Light and Dark.

### Phase 13 – Settings and release (2 weeks)
- Settings gets a **Features** pane with the checkboxes and toggles: ligatures, spell check, multi-cursor, Git, lint, Vega-Lite remote data.
- Replace `MPPreferences`, `PAPreferences`, `MASPreferences` with typed `Settings` and a standard Settings window (toolbar-style tabs, as macOS does today). Migrate old preference keys on first launch.
- Accessibility: VoiceOver, high-contrast theme, reduced motion.
- Localization: keep Transifex strings, move to String Catalogs.
- Sparkle 2 (delayed background check), notarization, hardened runtime.
- Rewrite `macdown-cmd` in Swift with ArgumentParser.
- Final budget verification against section 2.

## 7. Backlog After v1.0 (only if budgets stay green)

- Quick Look plug-in and Spotlight importer for Markdown.
- Table editing helpers (align pipes, Tab between cells).
- Image paste/drag into an `assets/` folder with relative link (no compression).
- Front matter form panel.
- Command palette (⌘⇧P).
- Git: file history viewer.
- URL scheme `macdown://open?path=`.
- Shortcuts app actions.

Deferred indefinitely: wiki links and backlinks, Graphviz, DOCX/EPUB, plug-in API.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Regressions during parser swap | Phase 1 snapshot corpus; review diffs by hand |
| tree-sitter grammar size and build effort | Grammars as SPM targets; first-wave set only; lazy-load others |
| TextKit 2 bugs in `NSTextView` | Keep the editor isolated in one module; fall back to TextKit 1 layout where needed |
| Config directory outside the sandbox | Distribute with Developer ID + notarization (current model); document it |
| Feature creep hurting speed | Every feature is checked against section 3; benchmarks run in CI |
| Losing users' old settings | One-time `MPPreferences` migration with tests |
| Multi-cursor bugs (IME, undo, auto-pair) | Fuzz tests against single-cursor results; simple fallback behavior when features conflict; setting to turn it off |
| macOS 27 design details are not known to this plan | Phase 12 starts with a spike on Apple's documentation; standard components only; Classic always works as a fallback |
| Vega-Lite size and remote data | Lazy load; remote data off by default; time and row limits |
| Toggle combinations multiply test cases | CI matrix runs benchmarks with all features on and all off, in both styles |

## 9. Release Plan

- **v1.0-alpha:** Phases 0–2.
- **v1.0-beta:** Phases 3–6.
- **v1.0:** Phases 7–9.
- **v1.1:** Phases 10–13 (Git, lint, Modern style, settings and polish).
- **v1.2+:** section 7 backlog.

## 10. Instructions for Claude Code Executing This Plan

1. One phase at a time, on its own branch (`modernize/phase-N-name`). Do not start a phase before the previous exit criteria pass.
2. Read a class fully and grep all callers before changing it; the codebase uses private APIs and categories that are easy to miss.
3. Delete legacy code once its replacement passes tests. Do not keep two implementations.
4. Never do slow work on the main thread. Every new async job must be cancellable.
5. Use standard AppKit controls and system colors. Do not add custom-drawn UI or a new visual style.
6. Do not add a third-party package without noting name, license and size in the PR description.
7. Run the tests and the benchmark target before each commit. A budget regression blocks the merge.
8. If this plan proves wrong, update this file in the same PR.
9. Every optional feature must be created only after its toggle is on, and must be fully torn down when the toggle is turned off.
