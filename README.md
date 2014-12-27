# MacDown

[![Build Status](https://travis-ci.org/uranusjr/macdown.svg?branch=master)](https://travis-ci.org/uranusjr/macdown)

MacDown is an open source Markdown editor for OS X, released under the MIT License. The author stole the idea from [Chen Luo](https://twitter.com/chenluois)’s [Mou](http://mouapp.com) so that people can [make crappy clones](https://twitter.com/remaerd/status/484914820408279040).

Visit the [project site](http://macdown.uranusjr.com/) for more information, or download [MacDown.app.zip](http://macdown.uranusjr.com/download/latest/) directly from the [latest releases](https://github.com/uranusjr/macdown/releases/latest) page.

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

If you wish to build MacDown yourself, you will need the following components/tools:

* OS X 10.8 SDK
* Git
* [CocoaPods](http://cocoapods.org)

> Note: Due to an [upstream bug](https://github.com/CocoaPods/CocoaPods/issues/2559), Xcode will fail to build certain dependencies if you use the latest version of CocoaPods (0.35 at the time of writing). To avoid the problem and build the project correctly, you need to install an older version of CocoaPods (0.34.4 is recommended), and use that to build the dependencies instead. See [comment in issue #220](https://github.com/uranusjr/macdown/issues/220#issuecomment-65014799) for detailed instructions.

The OS X 10.8 SDK should be bundled with Xcode 5, but not with Xcode 6+. If your version of Xcode does not contain the appropriate SDK, grab a copy of Xcode 5.1.1 from [Apple’s Developer Downloads page](https://developer.apple.com/downloads/index.action) (free developer ID required), which contains the 10.8 SDK. You may also find [this answer](http://stackoverflow.com/a/11424966/1376863) on StackOverflow useful if you want to use the SDK in Xcode 6 (or later).

After cloning the repository, run the following commands inside the repository root (directory containing this `README.md` file):

```bash
git submodule update --init --recursive
pod install
```

and open `MacDown.xcworkspace` in Xcode. The first command initialises the dependency submodule(s) used in MacDown; the second one installs dependencies managed by CocoaPods.

Refer to the official guides of Git and CocoaPods if you need more instructions. If you run into build issues later on, try running those commands again to update the dependencies.

## Discussion

[![Gitter](https://badges.gitter.im/Join Chat.svg)](https://gitter.im/uranusjr/macdown?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

Join our [Gitter channel](https://gitter.im/uranusjr/macdown?utm_source=share-link&utm_medium=link&utm_campaign=share-link) if you have any problems with MacDown. Any suggestions are welcomed, too!

You can also [file an issue directly](https://github.com/uranusjr/macdown/issues/new) on GitHub if you prefer so. But please, **search first to make sure no-one has reported the same issue already** before opening one yourself. MacDown does not update in your computer immediately when we make changes, so something you experienced might be known, or even fixed in the development version.

MacDown depends a lot on other open source projects, such as [Hoedown](https://github.com/hoedown/hoedown) for Markdown-to-HTML rendering, [Prism](http://prismjs.com) for syntax highlighting (in code blocks), and [PEG Markdown Highlight](https://github.com/ali-rantakari/peg-markdown-highlight) for editor highlighting. If you find problems when using those particular features, you can also consider reporting them directly to upstream projects as well as to MacDown’s issue tracker. I will do what I can if you report it here, but sometimes it can be more beneficial to interact with them directly.
