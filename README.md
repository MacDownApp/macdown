## MacDown简介
Mou 和 MacDown 是我在 Mac 下用过的两款优秀的 Markdown 编辑器。之前一直使用的是 Mou，但不知怎的最近 Mou 在保存时总有 4s 以上的卡顿，这让我很不爽，没找到有效的解决方法，于是我被迫去寻找其它的 MD 编辑器。我尝试过很多种，但总觉得没有 Mou 体验好，最终让我找到了 MacDown——OS X下开放源代码 Markdown 编辑器。

背后的故事
很有兴趣关注了这两款软件的作者及背后的故事，发现很有趣，在评测两款软件之前我们先八一八故事吧。

>Mou 的作者罗晨，个人主页：http://chenluois.com/，现居住天津，自由职业者。

>MacDown 的作者Tzu-ping Chung，个人主页：https://uranusjr.com/，现居住台北市，应该是台湾同胞吧。

根据 MacDown 作者的介绍，他曾经一度是 Markdown 的重度用户，而使用的编辑器基本是 Mou，但 Mou 可以处理fenced code blocks，却对代码高亮不支持，同时在渲染 Markdown 时也有 bug，这让他很苦恼。Mou 的作者当时正准备转手该软件，一直没有更新，所以，他就开始从头开始模仿 Mou 写一个，因为是 Markdown editor for Macs，所以取名为 MacDown。

MacDown 作者 Chung 在征得 Mou 作者 Luo 的同意使用了 Mou 的几款主题，发布了 MacDown 的原始版本。Luo 最后发现 MacDown 时，很气愤，并指责 Chung 是 copycat，意思是 MacDown 山寨了 Mou。Chung 也意识到确实是自己抄袭了 Mou 很多东西，根据某条推文的建议（并不是Luo发布的），将之前 github 中项目描述 改成了：

MacDown is an open source Markdown editor for OS X, released under the MIT License. The author stole the idea from Chen Luo’s Mou so that people can make crappy clones. ^1

比较详细的情节可以参见 Chung 的博客。至于 MacDown 和 Mou 的关系是怎样的，是不是 MacDown 就是不道德地克隆了 Mou 呢？这个每个人都有自己的看法，这里就不讨论了。

欣喜的是，目前两款软件都找到自己的发展模式，Mou 已经完成了众筹，即将发布 1.0 版本，如果有对 Mou 有情怀的同学可以支持作者；MacDown 依旧会走自己开源的道路。

Chung 的一句话也道出了我的心声：

Let’s focus on making better software for everyone.
好了，八卦完了，最后我要对两位作者表示由衷的谢意，贡献给我们好用的软件！下面我会根据我体验，分别提一下两款软件各自的特色地方。

共同功能
提供丰富的简洁大方好看的主题，同时支持自定义
提供丰富的渲染 Markdown 之后的 CSS 样式，同时支持自定义样式
英文单词的自动补全功能，按下 Esc 键列出补全的列表
字符、单词统计功能
支持 fenced code blocks
TeX 数学公式的支持
支持导出 HTML 和 PDF 两种格式
便捷的快捷键操作
... 
###MacDown 特色
####代码高亮
Mou 和 MacDown 都支持 fenced code blocks（前后三个反引号可以表示代码块），但 MacDown 支持加语言标识符实现代码高亮，这对程序员来说简直是福音啊，非常棒的功能。

MacDown 支持代码高亮
MacDown 支持代码高亮
####GFM Task List 支持
MacDown 支持 Task list，有了这个功能，你可以将你的 MD 编辑器立马变成 TODO list，是不是很赞？

MacDown 对 Task list 的支持
MacDown 对 Task list 的支持
####Jekyll Front-matter 支持
很多人使用 Jekyll 作为博客引擎，这时 Jekyll 的前面那段该怎么去渲染呢？MacDown 和 github 一样可以支持。

MacDown 对 Jekyll front-matter 的支持
MacDown 对 Jekyll front-matter 的支持（作者海风林影  [编辑器 Mou/MacDown 大 PK](http://www.jianshu.com/p/6c157af09e84)）

###自动链接
<https://github.com/Mingriweiji-github?tab=repositories>

1. [Markdown 中文版语法说明](http://wowubuntu.com/markdown/#list)
2. [Markdown之表格的处理](http://www.ituring.com.cn/article/3452)
3. [表格宽度调整 点我](http://www.ituring.com.cn/article/details/8367)
4. [Markdown之写作篇](http://www.jianshu.com/p/PpDNMG)

- [markdown简明语法](http://ibruce.info/2013/11/26/markdown/)
- [作者@Mingriweiji Github](https://github.com/Mingriweiji-github?tab=repositories)
- [创始人 John Gruber 的 Markdown 语法说明](http://daringfireball.net/projects/markdown/syntax)


[![](https://img.shields.io/github/release/uranusjr/macdown.svg)](http://macdown.uranusjr.com/download/latest/)
![Total downloads](https://img.shields.io/github/downloads/uranusjr/macdown/latest/total.svg)
[![Build Status](https://travis-ci.org/uranusjr/macdown.svg?branch=master)](https://travis-ci.org/uranusjr/macdown)


MacDown is an open source Markdown editor for OS X, released under the MIT License. The author stole the idea from [Chen Luo](https://twitter.com/chenluois)’s [Mou](http://mouapp.com) so that people can [make crappy clones](https://twitter.com/remaerd/status/484914820408279040).

Visit the [project site](http://macdown.uranusjr.com/) for more information, or download [MacDown.app.zip](http://macdown.uranusjr.com/download/latest/) directly from the [latest releases](https://github.com/uranusjr/macdown/releases/latest) page.

## License

MacDown is released under the terms of MIT License. You may find the content of the license [here](http://opensource.org/licenses/MIT), or inside the `LICENSE` directory.

You may find full text of licenses about third-party components in the `LICENSE` directory, or the **About MacDown** panel in the application.
macdown是OS X的一个开放源码的markdown编辑器，MIT许可下发布。
作者从陈罗偷走的想法...
更多信息请访问项目网站，或下载最新版本macdown.app.zip直接从网页。
####许可证
macdown是麻省理工学院授权条款下发布。你可以在这里找到许可证的内容，或者在许可证目录里面。
你会发现在许可目录的第三方组件许可全文，或在macdown面板中的应用

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

* OS X SDK (10.8 or later)
* Git
* [Bundler](http://bundler.io)

You may also need to install Xcode’s command line tools with the following command:

    xcode-select --install

> Note: Due to multiple upstream bugs, Xcode will fail to build certain dependencies if you use the CocoaPods 0.36.x ([reason](https://github.com/CocoaPods/CocoaPods/issues/2559)) or 0.37.x ([reason](https://github.com/Bertrand/handlebars-objc/issues/15)). To avoid the problem we use a Gemfile to specify the version, and thus you should add `bundle exec` before running a CocoaPods command.

An appropriate SDK should be bundled with Xcode 5 or later versions.

### Environment Setup

After cloning the repository, run the following commands inside the repository root (directory containing this `README.md` file):

    git submodule init
    git submodule update
    bundle install
    bundle exec pod install

and open `MacDown.xcworkspace` in Xcode. The first command initialises the dependency submodule(s) used in MacDown; the second one installs dependencies managed by CocoaPods.

Refer to the official guides of Git and CocoaPods if you need more instructions. If you run into build issues later on, try running the following commands to update dependencies:

    git submodule update
    bundle exec pod install

## Discussion

[![Gitter](https://badges.gitter.im/Join Chat.svg)](https://gitter.im/uranusjr/macdown?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

Join our [Gitter channel](https://gitter.im/uranusjr/macdown?utm_source=share-link&utm_medium=link&utm_campaign=share-link) if you have any problems with MacDown. Any suggestions are welcomed, too!

You can also [file an issue directly](https://github.com/uranusjr/macdown/issues/new) on GitHub if you prefer so. But please, **search first to make sure no-one has reported the same issue already** before opening one yourself. MacDown does not update in your computer immediately when we make changes, so something you experienced might be known, or even fixed in the development version.

MacDown depends a lot on other open source projects, such as [Hoedown](https://github.com/hoedown/hoedown) for Markdown-to-HTML rendering, [Prism](http://prismjs.com) for syntax highlighting (in code blocks), and [PEG Markdown Highlight](https://github.com/ali-rantakari/peg-markdown-highlight) for editor highlighting. If you find problems when using those particular features, you can also consider reporting them directly to upstream projects as well as to MacDown’s issue tracker. I will do what I can if you report it here, but sometimes it can be more beneficial to interact with them directly.

## Tipping

If you find MacDown suitable for your needs, please consider [giving me a tip through PayPal](http://macdown.uranusjr.com/faq/#donation). Or, if you perfer to buy me a drink *personally* instead, just [send me a tweet](https://twitter.com/uranusjr) when you visit [Taipei, Taiwan](http://en.wikipedia.org/wiki/Taipei), where I live. I look forward to meeting you!

