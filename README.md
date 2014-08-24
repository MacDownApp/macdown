# MacDown

[![Build Status](https://travis-ci.org/uranusjr/macdown.svg?branch=master)](https://travis-ci.org/uranusjr/macdown)

MacDown is an open source Markdown editor for OS X, released under the MIT License. The author stole the idea from [Chen Luo](https://twitter.com/chenluois)’s [Mou](http://mouapp.com) so that people can [make crappy clones](https://twitter.com/remaerd/status/484914820408279040).

Visit the [project site](http://macdown.uranusjr.com/) for more information, or download [MacDown.app.zip](http://macdown.uranusjr.com/download/latest/) directly from the [latest releases](https://github.com/uranusjr/macdown/releases/latest) page.

## License

MacDown is released under the terms of MIT License. You may find the content of the license [here](http://opensource.org/licenses/MIT), or inside the `LICENSE` directory.

You may find full text of licenses about third-party components inside in the `LICENSE` directory, or the **About MacDown** panel in the application.

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

If you wish to build MacDown yourself, you will need Git and [Cocoapods](http://cocoapods.org). After you clone the repository, run the following command inside the repository root (directory containing this `README.md` file):

```bash
git submodule init
git submodule update
pod install
```

and open `MacDown.xcworkspace` in Xcode. The first two commands intialise the dependency submodule(s) used in MacDown; the last one installs dependencies managed by Cocoapods.

Refer to the official guides of Git and Cocoapods if you need more instructions. If you run into build issues, try running `git submodule update` and `pod install` again to update the dependencies.
