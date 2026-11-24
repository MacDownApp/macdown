# Vault Viewer (iPad)

A read-only viewer for an Obsidian vault in iCloud Drive. No editing. Sidebar with the notes,
LaTeX (KaTeX), Mermaid diagrams, code highlighting, and predefined reading themes.

Built for one iPad (iPadOS 16 or newer) and not meant for distribution.

## Install on your iPad

The app is one file: `build/ipad/VaultViewer.ipa` (create it with `Tools/ipad/build-ipa.sh`).
An iPad only runs apps that are signed for it, and signing needs *your* Apple ID, so pick one:

**A. Xcode (most reliable)**
1. Connect the iPad, turn on Developer Mode (Settings > Privacy & Security).
2. `open Viewer/VaultViewer.xcodeproj`, select the *VaultViewer* target > Signing & Capabilities,
   choose your Team (a free Apple ID works), and change the Bundle Identifier to something unique.
3. Choose your iPad as the run destination and press Run.
   With a free Apple ID the app stops opening after 7 days; run it again to renew.

**B. Sideloadly or AltStore with the `.ipa`** (no Xcode project needed)
1. Run `Tools/ipad/build-ipa.sh` (unsigned `.ipa`).
2. Drag `build/ipad/VaultViewer.ipa` into Sideloadly (or AltStore), sign in with your Apple ID, install.

**C. Signed `.ipa` from the command line** (needs your Team ID and the iPad registered to your account)
`DEVELOPMENT_TEAM=ABCDE12345 BUNDLE_ID=com.you.vaultviewer Tools/ipad/build-ipa.sh`, then
`xcrun devicectl device install app --device <iPad name or id> build/ipad/VaultViewer.ipa`.

## First start
Tap *Choose Folder…* and pick your vault folder (Files > iCloud Drive > Obsidian > your vault). The app
remembers it. Notes that are not downloaded yet appear in the list and download when you open them.

## What it understands
- Markdown with tables, task lists (read-only), footnotes, ~~strikethrough~~, `==highlight==`
- Math: `$x^2$` and `$$...$$` (KaTeX, works offline)
- Mermaid diagrams (` ```mermaid `, follows the theme's light or dark)
- Code highlighting for most languages
- PDFs: listed in the sidebar and searchable like notes, opened in a PDF viewer (select text, find in the document,
  page counter). In notes, `![[paper.pdf]]` shows a tappable card; `![[paper.pdf#page=3]]` and `[[paper.pdf#page=3|alias]]`
  open that page; ordinary links such as `[paper](docs/paper.pdf)` work too
- Obsidian: `[[wikilinks]]` (with `#heading` and `|alias`), `![[image.png|300]]`, audio and video embeds,
  note and section embeds (`![[Note#Heading]]`), callouts (`> [!tip] Title`, foldable with `+`/`-`),
  `#tags`, `%%comments%%`, front matter shown as a collapsible *Properties* box

## Not supported
Editing; dataview, canvas, or other plugins; block references (`^id`); password-protected PDFs and PDFs over 300 MB;
tag search or backlinks; live sync (the app reloads when it comes to the front, or use *Reload Vault*).

## Development
- `ViewerCore` is a Swift package (`Viewer/Package.swift`) that builds and tests on a Mac: `cd Viewer && swift test`.
- The app target is generated: `ruby Tools/ipad/make_project.rb` (do this after adding files to `Viewer/App`).
- KaTeX, Mermaid, Prism and the YAML themes are shared with the macOS app and referenced in place.
- The simulator is not available on the machine this was written on, so the SwiftUI screens have been
  compiled for the iPad but not run. The renderer, file access rules and web page are tested on macOS,
  including in a real web view.
