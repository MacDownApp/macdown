# MacDown

MacDown is an open source Markdown editor for OS X, released under the MIT License. It is heavily influenced by [Chen Luo](https://twitter.com/chenluois)’s [Mou](http://mouapp.com).

## Why Another Markdown Editor?

I like Mou. I write Markdown all the time, and since I use OS X on a daily basis, Mou is my go-to editor whenever I wish to generate something with markup. But I had always wanted something more.

I was shocked when Chen Luo announced that he felt he could nout actively continue the development, and wished to [sell the ownership of Mou](http://www.v2ex.com/t/112732). [No suitable offers surfaced](http://www.v2ex.com/t/113734) (I honestly do not think there will be, either), and I decided that instead of waiting for others to do something about this, I should act myself.

I don’t have nearly enough money to match Chen Luo’s purposed offer, but I do have my own pocket of tricks and some free time. So I started from scratch, spent some weekends hacking together my own solution. And this is the result.

## What’s MacDown?

MacDown is heavily influenced by Mou, and they do share a lot in common both in UI and logic underneath. There are, still, some differences. Here are some more important features MacDown has to offer:

### Markdown Rendering

[Hoedown](https://github.com/hoedown/hoedown) is used internally to render Markdown into HTML. This makes MacDown’s live preview both efficient and very configurable. It also supports lots of non-standard syntactic features, including the very widely-used [fenced code blocks with language identifiers](https://help.github.com/articles/github-flavored-markdown#fenced-code-blocks). You can find all the available configurations in the Preferences. Try them out!

### Syntax Highlighting

MacDown offers syntax highlighting in fenced code blocks with language identifiers through [Prism](http://prismjs.com).

![](http://d.pr/i/VuJO+)

### Auto-completion

I am spoiled, as a programmer, by some pretty advanced auto-completion various IDEs offer. I implemented MacDown’s auto-completion to suit my own need. Hope it suits you too—or you can turn it off if you wish to.

## FAQ

### Why Didn’t You Use Swift?

MacDown was initiated three days after Apple announced Swift. While it is truely a nice language, [I do not think it is quite production-ready yet](http://swiftwtf.tumblr.com). I would very much like to use it in the future, though.

### Why OS X?

I am a cross-platform developer, and chould have implemented the whole thing with a cross-platform framework. But those frameworks usually feel alient, especially on OS X. I might port this if there’s time, though. Still considering options.

## License

MacDown is released under the terms of MIT License. You may find the content of the license [here](http://opensource.org/licenses/MIT), or inside the `LICENSE` directory.

You may find full text of licenses about third-party components inside in the `LICENSE` directory, or the **About MacDown** panel in the application.

The following editor themes are extracted from [Mou](http://mouapp.com):

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

by courtesy of Chen Luo.

The Github Markdown CSS is modified from the [Gist](https://gist.github.com/andyferra/2554919) posted by Andy Ferra.

