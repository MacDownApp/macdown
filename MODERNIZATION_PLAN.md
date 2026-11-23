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

## Status (2026-11-23)

Honest summary of what exists. "Engine" means the logic is written, tested and committed but nothing in the app calls it yet.

| Phase | State |
|---|---|
| 0 Build | Done. CocoaPods stays until the last pod is replaced. |
| 1 Seams, benchmarks | Done. |
| 2 Markdown core | Done. cmark-gfm engine is live in the app; Hoedown is gone. |
| 3 Editor | **Engine only:** multi-cursor edit logic (fuzz tested). Not started: TextKit 2, tree-sitter highlighting, wiring multi-cursor into the text view, spell-check toggle. |
| 4 WKWebView | **Done, with gaps** (see Phase 4). The old `WebView`, its private headers, the DOM helpers and the MathJax listener are gone. |
| 5 KaTeX | **Done.** Bundled KaTeX 0.16.11, loaded only for pages with math. MathJax is gone. See Phase 5. |
| 6 Mermaid, Vega-Lite | **Done, not fully re-verified.** See Phase 6. |
| 7 Themes | **Live in the preview:** YAML themes, 9 built-in, live reload, `theme:` in `config.yaml`. Not started: editor colors from the theme, theme picker UI, converting the old Mou themes. |
| 8 Fonts | Not started. |
| 9 Sidebar | **Engine only:** lazy markdown tree, Quick Open matcher, FSEvents watcher, outline. No sidebar UI yet. |
| 10 Git | **Engine only:** status, hunks, gutter markers, stage, commit, branches, remote. No UI yet. Uses the system `git`, not libgit2 (see Phase 10). |
| 11 Lint | **Engine only:** 8 rules. No editor marks or settings yet. |
| 12 Modern style | Not started. |
| 13 Settings, release | Not started. `AppConfig` parses every toggle, but only `theme` is read by the app. |

Branches are stacked: `modernize/phase-0-build` -> `phase-1-seams` -> `phase-2-markdown-core` -> `phase-3-engines` (latest).

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

### Phase 0 – Revive the build (1 week) — DONE (with one change)
- Done: clean build and tests on Xcode 27; deployment target raised to **macOS 13** (Xcode 27 cannot target below macOS 12); GitHub Actions replaces Travis; Swift enabled (bridging header, Swift 5 language mode); Yams added through Swift Package Manager; `Tools/sync_xcodeproj.rb` keeps new Swift files and bundled folders in the Xcode project.
- **Change from the original plan:** CocoaPods is **not** removed in Phase 0. Most pods are replaced by later phases (hoedown, LibYAML and handlebars in Phase 2; MASPreferences, PAPreferences, Sparkle, GBCli, JJPluralForm in Phase 13). Vendoring them now only to delete them later is wasted work. Each pod is removed in the phase that replaces it; CocoaPods goes away when the last pod does.
- Still open: universal-binary check, Sparkle 2 (Phase 13), Transifex upload step that Travis used to run (re-add to GitHub Actions in Phase 13).
- The build needs `pod install` with the system CocoaPods (the pinned Bundler gems in `Gemfile.lock` do not install on current Ruby).

### Phase 1 – Decompose, seams, benchmarks (1–2 weeks) — DONE (with changes)
- Done: `MPMarkdownEngine` protocol and `MPHoedownEngine` (all Hoedown code moved out of `MPRenderer`; `MPRenderer` only sees the protocol). Golden-file tests: 20 documents in two option sets, 40 goldens (`MacDownTests/Snapshots`). Benchmarks with hard limits plus a recorded baseline (`docs/benchmarks.md`). `os_signpost` around each render. Three categories moved out of `MPDocument` into their own files.
- **Changes from the original plan:**
  - `MPDocument` is **not** cut to 600 lines now (1949 lines). What remains (export, scroll sync, WebView delegates, editor setup) is tied to the old `WebView` and `peg-markdown-highlight`, which Phases 3 and 4 replace. Splitting it now would be work thrown away. The split happens inside those phases.
  - Only the Markdown seam is defined now. The other seams (`PreviewView`, `SyntaxHighlighter`, `GitProvider`) are defined at the start of the phase that implements them, so they match a real implementation.
  - The Phase 2 parser must stay within about 3 times the Hoedown benchmark numbers.
- Known Hoedown quirks recorded in the goldens (fix in Phase 2 or 5): `$5 and $10` is turned into math; `\[ ... \]` display math is not recognized; code blocks with no language get `language-none`.

### Phase 2 – Markdown core (2 weeks) — DONE (with changes)
- Done: Hoedown is gone (engine, patch files, pod). The app now renders with **cmark-gfm** through `MPMarkdownEngine` (`CMarkEngine`, Swift). Supported: tables, task lists, strikethrough, autolinks, footnotes, YAML front matter, `[TOC]`, heading ids (`toc_N`), GitHub alerts (`> [!NOTE]`), math (`$..$`, `$$..$$`, `\(..\)`, `\[..\]`), `==highlight==`, `^superscript`, `_underline_`, `"quote"`, smart punctuation, hard wrap, code blocks in the Prism format with line numbers and `language:information`.
- **Changes from the original plan:**
  - The engine uses **cmark-gfm directly**, not `swift-markdown`. `swift-markdown` has no footnote support (footnotes are on by default in MacDown) and is slower. MacDown's own syntax is handled by `MarkdownExtensionMasker` (code-aware, one linear pass). If a typed AST is needed for the outline or scroll sync, add it in the phase that needs it.
  - `CMARK_OPT_UNSAFE` is on (raw HTML passes through, as before). The sanitizer setting belongs to Phase 4.
  - LibYAML and handlebars-objc stay for now: front matter and the page template still use them. They go with the Phase 4 / Phase 7 rewrites.
- Behavior changes to know about (all follow CommonMark): `#Heading` without a space is no longer a heading; `* - +` list markers that change start a new list; `_` never makes emphasis inside a word; the "fenced code" preference cannot turn fences off; footnote markup is `<section class="footnotes">` (no bundled style uses footnotes). Fixed on the way: `$5 and $10` is no longer math, `\[..\]` and `$$..$$` display math work, `\|` in table cells works.
- Also fixed (found while measuring with optimization on): `MPToolbarController` read past the end of two C arrays, which crashed any optimized build at launch.
- 114 tests pass: 20-document golden corpus in two option sets, behavior tests, masker tests (including pathological input), benchmarks.

### Phase 3 – Native editor and highlighting (3 weeks)
- **TextKit 2** `NSTextView` subclass.
- **tree-sitter** highlighting (incremental): `tree-sitter-markdown` plus injected grammars for fenced code. First-wave languages: Swift, Objective-C, C, C++, Python, JavaScript, TypeScript, JSON, YAML, TOML, Shell, HTML, CSS, SQL, Go, Rust, Java, Ruby, PHP, Diff, LaTeX. Others load on demand; unknown languages are plain text.
- Same grammars generate preview code highlighting in Swift (`<span class="tok-…">`); Prism removed.
- Editing: list continuation, auto-pairing, indent handling, find/replace with regex (system find bar), word count in status area.
- **Multi-cursor:** add caret with ⌥-click, add next match with ⌘D, select all matches, column selection with ⌥-drag, Esc to return to one caret. Use `NSTextView` multiple `selectedRanges` for selection and `shouldChangeText(inRanges:replacementStrings:)` for edits; draw extra carets in a lightweight overlay. All edits from one keystroke form **one undo group**. Must work with IME composition, auto-pairing, and list continuation (these may fall back to simple behavior with multiple carets). Include fuzz tests that compare multi-cursor edits with repeated single-cursor edits.
- **Spell check toggle:** attach the system checker only when enabled; skip code spans, code blocks, URLs, and front matter.
- Remove `peg-markdown-highlight`, `Dependency/` submodule, `syntax_highlighting.json`.
- Exit: 1 MB file typing stays under 16 ms; highlight is incremental.

### Phase 4 – WKWebView preview (2 weeks) — DONE, with gaps
- Done: `WKWebView` created in code by `MPPreviewController` (the nib holds a placeholder; a URL scheme handler must exist before the web view). Local files are served through `macdown-file://` (`PreviewSchemeHandler`: only our own pages may load files, no CORS headers, folders and missing files give 404, range requests work). `file://` references in the page and the MathJax CDN address are rewritten (`PreviewURL.rewrite`). Links go through a delegate (local `.md` files open in MacDown, other links in the browser, `#anchors` stay on the page). Scroll sync keeps its algorithm, using heading positions and page height that the page reports. Word count, divider color, zoom (`pageZoom`), print and PDF export (`printOperation`) are ported. Drops on the preview are refused. A killed web content process reloads the page. The private `WebCache` call is gone.
- 249 tests pass, including a real `WKWebView` (local images, scripts, styles, names with spaces and accents, ranges, link clicks, MathJax signal, metrics, scroll, text count, color, print) and a real document window loaded from the nib.
- **Not done from the original list (still open):**
  - DOM patching and a warm web view: every render still reloads the whole page, as before. Expect the same brief flash as the old preview; scroll position is restored after load.
  - Raw HTML sanitizer setting and a Content Security Policy.
  - Moving scroll sync to AST source positions.
  - The preview was **not looked at by eye** in a running app. Things worth checking by hand: print and PDF export output, MathJax typesetting, zoom with large editor fonts, and scroll sync feel.
- The old `-webView:doCommandBySelector:` copy handler (adds `public.html` to the pasteboard) was dropped: `WKWebView` puts HTML on the pasteboard by itself. Verify with a copy from the preview.

### Phase 5 – LaTeX / math (1 week) — DONE
- Done: **KaTeX 0.16.11** is bundled in `Resources/KaTeX` (woff2 fonts only, 600 KB) and works offline. A small loader (`katex-init.js`) runs on every page when math is enabled, checks the text outside code for `\(` or `\[`, and loads KaTeX only if it finds some. It then renders with auto-render and sends the same "math done" signal the scroll sync already waits for. MathJax and its CDN dependency are removed; the preview no longer needs the network for math.
- Math syntax is found by the Phase 2 masker (not by JavaScript guessing): `$x$` (when "inline dollar" is on), `$$..$$`, `\(..\)`, `\[..\]`. Currency such as `$5 and $10`, math inside code, and escaped dollars stay text.
- Exported HTML cannot read files inside the app, so it links KaTeX from jsDelivr with a pinned version and an embedded init script. Not done: Subresource Integrity hashes on those links.
- Behavior to know: KaTeX auto-render stops at math it cannot delimit (for example `\(\frac{\)` with unbalanced braces) and leaves that line as text; an unknown command is drawn in red.
- The preference is still called "MathJax" in the settings window and in code (`htmlMathJax`). Renaming it touches localized strings; it moves to the Phase 13 settings rewrite.
- Not done from the original list: rendering math to images for PDF export (PDF export prints the web view, so formulas are already vector text); highlighting LaTeX in the editor (needs the Phase 3 tree-sitter work).
- 9 new tests in a real web view (typesetting, fonts load offline, lazy loading, code and currency, errors, 500 formulas in a fraction of a second, export, preference off).

### Phase 6 – Mermaid and Vega-Lite (2 weeks) — DONE, last full test run skipped
- Done: **Mermaid 11.17.2** (3.5 MB, one file, all diagram types) and **Vega-Lite 5.23** (Vega 5.33, Vega-Embed 6.29, js-yaml 4.3) are bundled in `Resources/Diagrams`. Three small loaders (`diagram-common.js`, `mermaid-init.js`, `vega-init.js`) load a library only if the page has a block that needs it. Mermaid blocks follow the preference (and no longer need syntax highlighting to be on). Charts are always on: ```` ```vega-lite ```` (and ```` ```vega ````) with a JSON or YAML spec.
- Charts: colors follow the page text color, background is transparent. Data from the web is blocked unless `charts.vega-lite-remote-data: true` is set in `config.yaml`; local data files next to the document work. More than 100,000 inline rows, a bad spec, or a load that fails shows a message under the (still visible) source block; Vega itself would draw an empty chart, so every load failure is recorded and reported. Each diagram has a 10 second limit.
- Mermaid: follows a dark page, security level strict, finished SVG is cached in page storage while the app runs. Errors keep the source visible with a message.
- Exported HTML embeds the loaders; with no `src` they load pinned CDN versions.
- Graphviz is removed (`viz.js`, 3.7 MB). `dot` blocks show as code. The Graphviz preference still exists but does nothing.
- New: `DiagramPreviewTests` (22 tests in a real web view). They passed in isolation before the last edits (all but two selector mistakes in the tests themselves, then fixed). **A final full-suite run was not completed** at the user's request, and the last edits to `vega-init.js` (load-failure reporting) were verified only by the isolated diagram tests that passed afterwards.
- Not done: Mermaid theme from the YAML theme colors (it follows light/dark only), SVG export of charts, Subresource Integrity on the CDN links, a setting to turn charts off.
- Lesson recorded: overlapping `xcodebuild` runs interrupt each other and looked like hangs. Run one at a time.

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
- **Decision changed:** the system `git` is used (async, no shell, prompts off, time limit), not libgit2. The app is not sandboxed, so this is possible, and the user's own git config, credential helpers, SSH agent and hooks then work exactly as in Terminal. No extra dependency or build time.
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
