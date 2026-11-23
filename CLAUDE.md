# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

MacDown is an open-source Markdown editor for macOS, written in Objective-C (Cocoa, AppKit, WebView). It has a split view: an `NSTextView` editor on the left and a `WebView` HTML preview on the right.

## Setup & Build

Always open `MacDown.xcworkspace` (not the `.xcodeproj`), since dependencies come from CocoaPods.

```
git submodule update --init
bundle install
bundle exec pod install          # use Bundler; system CocoaPods may be too old
make -C Dependency/peg-markdown-highlight   # builds the editor syntax-highlighting parser
```

After pulling, re-run `git submodule update` and `bundle exec pod install` if builds break.

Run tests (same as CI, see `.travis.yml`):

```
xcodebuild -workspace MacDown.xcworkspace -scheme MacDown test
# single test class / method:
xcodebuild -workspace MacDown.xcworkspace -scheme MacDown test -only-testing:MacDownTests/MPUtilityTests
xcodebuild -workspace MacDown.xcworkspace -scheme MacDown test -only-testing:MacDownTests/MPUtilityTests/testMethodName
```

Targets: `MacDown` (app), `MacDownTests` (XCTest, `MacDownTests/MP*Tests.m`), `macdown-cmd` (command-line launcher `macdown`, uses GBCli).

The GitHub-2020 preview stylesheet is generated from Sass: `Tools/GitHub-style-generator` (`make` there, requires node-sass via npm) writes `MacDown/Resources/Styles/GitHub-2020.css`. Don't hand-edit that file.

## Architecture

Source lives in `MacDown/Code/`, with the `MP` class prefix throughout:

- **Application/** – `MPMainController` (app delegate, menus, prefs windows, plug-in loading), `MPToolbarController`, `MPPlugInController`, export panel accessory.
- **Document/** – the core. `MPDocument` is an `NSDocument` subclass owning the editor, preview, split view, scroll syncing, export (HTML/PDF), and file I/O. `MPRenderer` converts Markdown to HTML and feeds it back to the document through a data-source/delegate protocol; it uses Hoedown (with local patches in `Extension/hoedown_html_patch.c`) and Handlebars templates from `Resources/Templates`. `MPAsset` models the CSS/JS assets (styles, Prism, MathJax, etc.) injected into the rendered HTML.
- **Preferences/** – `MPPreferences` wraps `NSUserDefaults` (via PAPreferences) and is the single source of settings; one view controller per MASPreferences pane.
- **View/** – `MPEditorView` (editor text view) and `MPDocumentSplitView`.
- **Extension/** – Objective-C categories and helpers (autocomplete, HTML tabularize, color parsing, pasteboard types, private WebView headers, etc.).
- **Utility/** – globals, shared helpers, the plug-in protocol (`MPPlugIn`), MathJax listener, and Homebrew subprocess helper (for installing Jekyll/Graphviz-type dependencies).

Rendering flow: editor text change → `MPDocument` → `MPRenderer` (Hoedown → HTML, wrapped in a template with selected style/highlighting/MathJax assets) → loaded into the preview `WebView`. Editor syntax highlighting is separate: it uses `Dependency/peg-markdown-highlight` (a git submodule that must be built with `make`).

Other directories: `MacDown/Resources` (styles, themes, templates, JS/CSS, Prism), `MacDown/Localization` and `MacDownTests/*.lproj` (translations managed via Transifex; `Tools/import_translations.py`), `Tools/` (release/version scripts; `generate_version_header.sh` and `update_build_number.sh` run during the Xcode build), `Dependency/` (submodules: peg-markdown-highlight, version).

## Notes

- Deployment target is very old (Podfile `platform :osx, "10.8"`; PAPreferences pinned to 0.4.x until 10.8 is dropped), so avoid APIs newer than that without availability checks. The project uses the deprecated `WebView`, not `WKWebView`.
- Podfile uses a patched spec repo (`MacDownApp/cocoapods-specs`) for some libraries.
- See `CONTRIBUTING.md` for contribution guidelines.
