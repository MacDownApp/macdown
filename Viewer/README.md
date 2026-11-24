# Vault Viewer (iPhone and iPad)

A read-only viewer for an Obsidian vault in iCloud Drive. No editing. Sidebar with the notes,
LaTeX (KaTeX), Mermaid diagrams, code highlighting, PDFs, home screen widgets, custom fonts and 19 reading themes.

One universal app: the same `VaultViewer.ipa` installs on an iPhone and on an iPad (iOS / iPadOS 16 or newer;
widgets need 17). On an iPad the sidebar and the note sit side by side; on an iPhone the list comes first and a
note opens on top of it. Not meant for distribution.

## Install on your iPhone or iPad

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

## Appearance
Tap the **Aa** (sidebar) or the palette (note) button:
- **Themes (19):** Ayu (Light, Mirage, Dark), Catppuccin (Latte, Frappé, Macchiato, Mocha), Full Black (pure `#000000`,
  for OLED), Full White, E-Paper (ink on paper, no color), GitHub, Solarized, Nord, Dracula, One, Tomorrow Night.
  Dark themes also make the app's own bars dark.
- **Fonts:** pick a reading font and a code font, or type any installed font name. Bundled: **JetBrains Mono Nerd Font**
  and **Cartograph CF Nerd Font** (symbols from JetBrains fill any icon Cartograph lacks).
- **Text size:** slider (70% to 200%) and the two buttons in the note toolbar.
- **Folders in the sidebar:** tap anywhere on a folder row to open or close it. Open folders are remembered, and opening
  a note (also from a widget) opens the folders above it.

### About the Cartograph font
Cartograph CF is a commercial font, so it is **not in the git repository** (the repository is public). It is copied into
the build from your own font folder: `Tools/fonts/import-local-fonts.sh` copies `CartographCFNerdFont-*.ttf` from
`~/Library/Fonts` into `MacDown/Resources/Fonts` (git ignores `Cartograph*` there). The `.ipa` and Mac app you build
yourself contain it; a fresh clone without the files simply does not offer it. JetBrains Mono (SIL OFL) is in the repo
with its license.

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

## Widgets (iPadOS 17 or newer)
Long-press the Home Screen, tap **+**, and search for *Vault Viewer*.
- **Note** (small): a shortcut to one note. Edit the widget to choose it; without a choice it shows the note you
  changed last.
- **Folder** (medium and large): edit the widget to choose a folder (or the whole vault). It lists that folder's own
  notes, then a section for each of its sub-folders with their newest notes. The large size shows more rows.
- Tapping a note opens it in the app. Widgets update when the app reads the vault (open the app, or use
  *Reload Vault*); open the app once after installing so the widgets have something to show.

Widgets cannot open your vault themselves: the app writes a small index (note names, folders, dates, no note text)
into an App Group container, and the widgets read that. This needs the **App Groups** capability, so the signing
has to grant it. In Xcode that is automatic for the `group.<bundle id>` group; a free Apple ID may or may not allow
it. If a widget says *Open Vault Viewer once*, the group was not granted (the app itself still works).
The group is read from the signed app's provisioning profile, so re-signing with AltStore or Sideloadly can rename it
without breaking the link, but this has not been tried.

## Not supported
Editing; dataview, canvas, or other plugins; block references (`^id`); password-protected PDFs and PDFs over 300 MB;
tag search or backlinks; live sync (the app reloads when it comes to the front, or use *Reload Vault*).

## Development
- `ViewerCore` is a Swift package (`Viewer/Package.swift`) that builds and tests on a Mac: `cd Viewer && swift test`.
- The widget code is in `Viewer/Widget` (WidgetKit and App Intents); the snapshot, layout and links it uses are in
  `ViewerCore` and are tested (`WidgetTests.swift`). The widgets themselves have only been compiled, not run.
- Icons: `swift Tools/ipad/make_icons.swift <macOS icon> <Assets.xcassets/AppIcon.appiconset>` makes the iOS icon (light,
  dark and tinted) from MacDown's icon.
- The app target is generated: `ruby Tools/ipad/make_project.rb` (do this after adding files to `Viewer/App`).
- KaTeX, Mermaid, Prism and the YAML themes are shared with the macOS app and referenced in place.
- The simulator is not available on the machine this was written on, so the SwiftUI screens have been
  compiled for the iPad but not run. The renderer, file access rules and web page are tested on macOS,
  including in a real web view.
