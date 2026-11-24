# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

MacDown is an open-source Markdown editor for macOS, written in Objective-C with a growing Swift part (Cocoa, AppKit, WebKit). It has a split view: an `NSTextView` editor on the left and a `WKWebView` HTML preview on the right.

## Setup & Build

Always open `MacDown.xcworkspace` (not the `.xcodeproj`), since dependencies come from CocoaPods.

```
git submodule update --init
pod install                      # system CocoaPods; the pinned Bundler gems do not install on current Ruby
make -C Dependency/peg-markdown-highlight   # builds the editor syntax-highlighting parser
```

After pulling, re-run `git submodule update` and `pod install` if builds break. Requires Xcode 27; deployment target is macOS 13.

New Swift code lives in `MacDown/Code/Swift/` (tests in `MacDownTests/Swift/`). After adding or removing Swift files, or a bundled resource folder, run `ruby Tools/sync_xcodeproj.rb` to update the Xcode project. Swift packages (currently Yams) are declared in that script.

Run the app: `Tools/run.sh docs/demo.md` (builds Debug into `./build` and opens it; `docs/demo.md` shows math, Mermaid, Vega-Lite, alerts and more).

Run tests (same as CI, see `.github/workflows/ci.yml`):

```
xcodebuild -workspace MacDown.xcworkspace -scheme MacDown -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
# single test class / method:
xcodebuild -workspace MacDown.xcworkspace -scheme MacDown test -only-testing:MacDownTests/MPUtilityTests
xcodebuild -workspace MacDown.xcworkspace -scheme MacDown test -only-testing:MacDownTests/MPUtilityTests/testMethodName
```

Targets: `MacDown` (app), `MacDownTests` (XCTest, `MacDownTests/MP*Tests.m`), `macdown-cmd` (command-line launcher `macdown`, uses GBCli).

The GitHub-2020 preview stylesheet is generated from Sass: `Tools/GitHub-style-generator` (`make` there, requires node-sass via npm) writes `MacDown/Resources/Styles/GitHub-2020.css`. Don't hand-edit that file.

## Architecture

Source lives in `MacDown/Code/`, with the `MP` class prefix throughout:

- **Application/** – `MPMainController` (app delegate, menus, prefs windows, plug-in loading), `MPToolbarController`, `MPPlugInController`, export panel accessory.
- **Document/** – the core. `MPDocument` is an `NSDocument` subclass owning the editor, preview, split view, scroll syncing, export (HTML/PDF), and file I/O. `MPRenderer` converts Markdown to HTML (through the `MPMarkdownEngine` protocol; the engine is `MPCMarkEngine`, Swift, in `Swift/Markdown/`) and feeds it back to the document through a data-source/delegate protocol; it wraps the result in Handlebars templates from `Resources/Templates`. `MPAsset` models the CSS/JS assets (styles, Prism, MathJax, etc.) injected into the rendered HTML.
- **Preferences/** – `MPPreferences` wraps `NSUserDefaults` (via PAPreferences) and is the single source of settings; one view controller per MASPreferences pane.
- **View/** – `MPEditorView` (editor text view) and `MPDocumentSplitView`.
- **Extension/** – Objective-C categories and helpers (autocomplete, HTML tabularize, color parsing, pasteboard types, private WebView headers, etc.).
- **Utility/** – globals, shared helpers, the plug-in protocol (`MPPlugIn`), MathJax listener, and Homebrew subprocess helper (for installing Jekyll/Graphviz-type dependencies).

Rendering flow: editor text change → `MPDocument` → `MPRenderer` (cmark-gfm → HTML, wrapped in a template with selected style/highlighting/MathJax assets) → loaded into the preview `WKWebView` (`Swift/Preview/PreviewController`). Editor syntax highlighting is separate: it uses `Dependency/peg-markdown-highlight` (a git submodule that must be built with `make`).

Other directories: `MacDown/Resources` (styles, themes, templates, JS/CSS, Prism), `MacDown/Localization` and `MacDownTests/*.lproj` (translations managed via Transifex; `Tools/import_translations.py`), `Tools/` (release/version scripts; `generate_version_header.sh` and `update_build_number.sh` run during the Xcode build), `Dependency/` (submodules: peg-markdown-highlight, version).

## Markdown engine

`Swift/Markdown/CMarkEngine.swift`: front matter → `MarkdownExtensionMasker` (finds math, `==x==`, `^x`, `_x_`, `"x"` outside code, swaps in private-use placeholders) → cmark-gfm parse → rewrite headings, code blocks and alerts in the AST → cmark HTML → fill in TOC, task lists and placeholders. Options are semantic (`MPMarkdownRenderOptions`), built from preferences in `MPPreferences+Markdown`. Golden tests: `MacDownTests/Snapshots/{corpus,golden}`; after an intended output change re-record with `TEST_RUNNER_MACDOWN_RECORD_SNAPSHOTS=<abs path to Snapshots/golden>` and review the diff. Benchmarks: `docs/benchmarks.md`.

## New Swift modules (`MacDown/Code/Swift/`)

Headless and unit tested; several are not wired into the UI yet (see the Status table in `docs/MODERNIZATION_PLAN.md`).
- `Config/` – `AppConfig` (typed `config.yaml`).
- `Theme/` – `Theme`, `ThemeManager`, `ThemeCSS`, `ThemeService` (live: adds the generated stylesheet in `MPRenderer.baseStylesheets`).
- `Diagrams` (resources, not Swift): `Resources/Diagrams` loaders for Mermaid and Vega-Lite (lazy, offline in the app, pinned CDN in exported HTML).
- `Preview/` – `PreviewController`, `PreviewSchemeHandler`, `PreviewURL`.
- `Markdown/` – `CMarkEngine`, `MarkdownExtensionMasker`, `TableOfContents`, `AlertBox`, `DocumentOutline`.
- `Lint/` – `Linter` (8 rules, UTF-16 ranges).
- `Git/` – `GitRunner`/`GitRepository` (system git; async).
- `Workspace/` – `WorkspaceTree`, `FuzzyMatcher`, `DirectoryWatcher`.
- `Editor/` – `MultiSelection` (pure multi-cursor logic).

Gotcha: directory listings can return `/private/var/...` for `/var/...`. Never compare URLs or strip path prefixes; compare file names or build relative paths while walking.

## Preview (WKWebView)

`MPPreviewController` (Swift) creates the web view in code: the nib only holds a placeholder view, because a `WKURLSchemeHandler` must be set before a `WKWebView` exists. Local files are served through the custom scheme `macdown-file://` (same paths as `file://`; `PreviewSchemeHandler`); `PreviewURL.rewrite` converts `src/href="file://..."` in the page. The page reports heading positions and height (`PreviewScripts.metrics`) so scroll sync in `MPDocument` can stay synchronous; the math-done signal (`MathJaxListener.invokeCallbackForKey_('End')`, a shim kept from the MathJax days) comes from `Resources/KaTeX/katex-init.js`, which loads the bundled KaTeX only if the page has math. Exported HTML uses pinned jsDelivr links instead. Tests: `PreviewTests.swift` (real `WKWebView`), `DocumentPreviewIntegrationTests.swift` (real document window from the nib).

## iPhone/iPad viewer, fonts and themes

`Viewer/` is a separate universal iOS app (read-only Obsidian vault viewer) on the `ViewerCore` Swift package; see `Viewer/README.md`. Build with `Tools/ipad/build-ipa.sh`; regenerate the Xcode project with `ruby Tools/ipad/make_project.rb`. Themes (`MacDown/Resources/BuiltinThemes`, 19 YAML files) and `Theme/FontCatalog.swift` are shared by the macOS app and the viewer (symlinked into `Viewer/Sources/ViewerCore/Shared`). macOS fonts are set in `config.yaml` (`fonts: {body: ..., code: ...}`).

**Never commit `MacDown/Resources/Fonts/Cartograph*`.** It is a commercial font and the repository is public; `.gitignore` excludes it and `Tools/fonts/import-local-fonts.sh` copies it in from the owner's font folder. JetBrains Mono Nerd Font (OFL) is committed with its license.

## Modernization in progress

`docs/MODERNIZATION_PLAN.md` is the roadmap; follow it phase by phase. Swift pieces already in place: `Config/AppConfig` (typed `~/.config/macdown/config.yaml`, feature toggles with defaults) and `Theme/` (YAML themes; built-ins in `MacDown/Resources/BuiltinThemes`, user themes in `~/.config/macdown/themes`). Set `MACDOWN_CONFIG_DIR` to point the app at another config directory (tests do this).

## Notes

- Deployment target is macOS 13. The preview is a `WKWebView`; the old `WebView` and its private headers are gone.
- Podfile uses a patched spec repo (`MacDownApp/cocoapods-specs`) for some libraries.
- See `CONTRIBUTING.md` for contribution guidelines.
