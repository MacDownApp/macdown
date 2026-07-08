# MacDown

[![](https://img.shields.io/github/release/MacDownApp/macdown.svg)](http://macdown.uranusjr.com/download/latest/)
![Total downloads](https://img.shields.io/github/downloads/MacDownApp/macdown/latest/total.svg)
[![Tests](https://github.com/MacDownApp/macdown/actions/workflows/tests.yml/badge.svg)](https://github.com/MacDownApp/macdown/actions/workflows/tests.yml)


MacDown is an open source Markdown editor for OS X, released under the MIT License. The author stole the idea from [Chen Luo](https://twitter.com/chenluois)’s [Mou](http://mouapp.com) so that people can make crappy clones.

Visit the [project site](http://macdown.uranusjr.com/) for more information, or download [MacDown.app.zip](http://macdown.uranusjr.com/download/latest/) directly from the [latest releases](https://github.com/MacDownApp/macdown/releases/latest) page.

## Install

[Download](http://macdown.uranusjr.com/download/latest/), unzip, and drag the app to Applications folder. MacDown is also available through [Homebrew Cask](https://caskroom.github.io/):

    brew install --cask macdown

## Screenshot

![screenshot](assets/screenshot.png)

## License

MacDown is released under the terms of MIT License. You may find the content of the license [here](http://opensource.org/licenses/MIT), or inside the `LICENSE` directory.

You may find full text of licenses about third-party components in the `LICENSE` directory, or the **About MacDown** panel in the application.

The following editor themes and CSS files are extracted from [Mou](http://mouapp.com), courtesy of Chen Luo:

* Mou Fresh Air
* Mou Fresh Air+
* Mou Night
* Mou Night+
* Mou Paper
* Mou Paper+
* Tomorrow
* Tomorrow Blue
* Tomorrow+
* Writer
* Writer+
* Clearness
* Clearness Dark
* GitHub
* GitHub2

## Development

### Requirements

If you wish to build MacDown yourself, you will need the following components/tools:

* macOS SDK (12.0 or later; this is the current `MACOSX_DEPLOYMENT_TARGET`)
* A recent Xcode
* Git
* [Bundler](http://bundler.io)

> Note: Old versions of CocoaPods are not supported. Please use Bundler to execute CocoaPods, or make sure your CocoaPods is later than shown in `Gemfile.lock`.

> Note: The Command Line Tools (CLT) should be unnecessary. If you failed to compile without it, please install CLT with
>
>     xcode-select --install
>
> and report back.

An appropriate SDK should be bundled with your version of Xcode.

### Environment Setup

After cloning the repository, run the following commands inside the repository root (directory containing this `README.md` file):

    git submodule update --init
    bundle install
    bundle exec pod install
    make -C Dependency/peg-markdown-highlight

and open `MacDown.xcworkspace` in Xcode. The first command initialises the dependency submodule(s) used in MacDown; the second one installs dependencies managed by CocoaPods.

Refer to the official guides of Git and CocoaPods if you need more instructions. If you run into build issues later on, try running the following commands to update dependencies:

    git submodule update
    bundle exec pod install

### Notes on the WKWebView Preview Engine

The Markdown preview pane runs on `WKWebView` (the legacy, deprecated `WebView`
it used to run on has been fully removed). A few things follow from that if
you're working on the preview/rendering code:

* The rendered preview is written to a hidden sidecar file next to the open
  document (`.macdown-preview-<uuid>.html`, ignored by `.gitignore`) and
  loaded via `-loadFileURL:allowingReadAccessToURL:`, rather than loaded
  in-memory via `-loadHTMLString:baseURL:`. This is what lets the preview
  read local images/stylesheets from anywhere on disk; WKWebView otherwise
  restricts `file://` sub-resource loads to the loaded page's own directory.
* Local stylesheets/scripts (custom user styles, Prism, MathJax's init
  script) are embedded inline into the generated HTML rather than
  `<link>`/`<script src>`-referenced, for the same reason.
* MathJax itself still loads from the CDN (`cdnjs.cloudflare.com`) rather
  than a bundled copy, since only its small bootstrap file is vendored
  locally — the fonts/config/extensions it fetches relative to its own
  script URL at runtime aren't. Math rendering requires network access.
* Sparkle has been upgraded from 1.x to 2.x (`SPUStandardUpdaterController`).
  If you're testing auto-update, you'll need your own EdDSA key pair
  (`Sparkle/bin/generate_keys`) — the old DSA key mechanism is gone.

### Translation

Please help translation on [Transifex](https://www.transifex.com/macdown/macdown/).

![Transifex translation percentage](https://www.transifex.com/projects/p/macdown/resource/macdownxliff/chart/image_png/)

## Discussion

[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/MacDownApp/macdown)

Join our [Gitter channel](https://gitter.im/MacDownApp/macdown) if you have any problems with MacDown. Any suggestions are welcomed, too!

You can also [file an issue directly](https://github.com/MacDownApp/macdown/issues/new) on GitHub if you prefer so. But please, **search first to make sure no-one has reported the same issue already** before opening one yourself. MacDown does not update in your computer immediately when we make changes, so something you experienced might be known, or even fixed in the development version.

MacDown depends a lot on other open source projects, such as [Hoedown](https://github.com/hoedown/hoedown) for Markdown-to-HTML rendering, [Prism](http://prismjs.com) for syntax highlighting (in code blocks), and [PEG Markdown Highlight](https://github.com/ali-rantakari/peg-markdown-highlight) for editor highlighting. If you find problems when using those particular features, you can also consider reporting them directly to upstream projects as well as to MacDown’s issue tracker. I will do what I can if you report it here, but sometimes it can be more beneficial to interact with them directly.

## Tipping

If you find MacDown suitable for your needs, please consider [giving me a tip through PayPal](http://macdown.uranusjr.com/faq/#donation). Or, if you prefer to buy me a drink *personally* instead, just [send me a tweet](https://twitter.com/uranusjr) when you visit [Taipei, Taiwan](http://en.wikipedia.org/wiki/Taipei), where I live. I look forward to meeting you!

