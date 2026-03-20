# Markly

**Version 1.0.0** | March 2026

A free Markdown editor for macOS. Built for people who read and write Markdown every day.

Based on [MacDown](https://github.com/MacDownApp/macdown) by Tzu-ping Chung, rebuilt with modern features.

## Features

### Reading
- **Preview-first defaults** — existing files open in preview mode so you can just read
- **Per-file view mode memory** — remembers how you last viewed each file
- **3 view modes** — Editor Only, Preview Only, or Split (toggle from toolbar or Cmd+1/2/3)
- **Native macOS tabs** — merge windows into tabs

### Writing
- **Focus Mode** (Cmd+Opt+F) — dims everything except the paragraph you're writing
- **Typewriter Mode** (Cmd+Shift+T) — keeps cursor vertically centered
- **Weasel Word Highlighting** — color-coded detection of qualifiers, weasel words, indirect language, weak adverbs, and repeated words
- **Writing Stats** — word count, reading time, readability score

### Navigation
- **Sidebar** (Cmd+Opt+S) — file browser + document outline with heading navigation
- **Command Palette** (Cmd+Shift+K) — fuzzy search all commands

### Rendering
- **Mermaid diagrams** — always on, just write a mermaid code block
- **Graphviz** — always on
- **LaTeX math** — TeX-like math syntax with MathJax
- **Syntax highlighting** — always on for fenced code blocks
- **WikiLinks** — `[[note]]` links between Markdown files

### Export
- HTML, PDF, and DOCX

### Themes
- GitHub2 (default), Minimal Light, Minimal Dark, iA Writer, Clearness, Solarized

## Install

Download **Markly-1.0.0.dmg** from the latest release, open it, and drag Markly to your Applications folder.

### Build from Source

```
git clone https://github.com/Wirtzer/Markly.git
cd Markly
git submodule update --init --recursive
pod install
open MacDown.xcworkspace
```

Build and run in Xcode (Cmd+R).

## License

The original MacDown code is under the MIT License. See the `LICENSE` directory for details. All Markly additions are Copyright (c) 2026 Alex Wirtzer. All rights reserved. See [LICENSE.md](LICENSE.md).

Editor themes and CSS from [Mou](http://mouapp.com) by Chen Luo.
