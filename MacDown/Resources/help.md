# MacDown

![MacDown logo](http://macdown.uranusjr.com/static/base/img/logo-160.png)

Hello there! I’m **MacDown**, the open source Markdown editor for OS X.

Let me introduce myself.


## Markdown and I

**Markdown** is a plain text formatting syntax created by John Gruber, aiming to provide a easy-to-read and feasible markup.

The original Markdown syntax specification can be found [here](http://daringfireball.net/projects/markdown/syntax).

**MacDown** is created as a simple-to-use editor for Markdown documents. I render your Markdown contents real-time into HTML, and display them in a preview panel.

I support all the original Markdown syntaxes. Various non-standard ones can also be turned on/off from the **Markdown** preference pane:

![Markdown preferences pane](http://d.pr/i/RQEi+)

You can also specify extra HTML rendering options through the **Rendering** pane:

![Rendering preferences pane](http://d.pr/i/rT4d+)

And you can also configure various behaviors in the **General** preferences pane.

![General preferences pane](http://d.pr/i/rvwu+)

### Block Formatting

#### Table

This is a table:

First Header  | Second Header
------------- | -------------
Content Cell  | Content Cell
Content Cell  | Content Cell

You can align cell contents with syntax like this:

| Left Aligned  | Center Aligned  | Right Aligned |
|:------------- |:---------------:| -------------:|
| col 3 is      | some wordy text |         $1600 |
| col 2 is      | centered        |           $12 |
| zebra stripes | are neat        |            $1 |

The left- and right-most pipes (`|`) are only aesthetic, and can be omitted. The spaces don’t matter, either. Alignment depends solely on `:` marks.

#### <a name="fenced-code-block">Fenced Code Block</a>

This is a fenced code block:

```
p 'Hello world!'
```

You can also use waves (`~`) instead of back ticks (`` ` ``):

~~~
print('Hello world!')
~~~

In either case, you can add an optional language ID at the end of the first line:

```markup
<div>
    Copyright © 2014
    <a href="https://uranusjr.com">Tzu-ping Chung</a>.
</div>
```

The language ID will be used to highlight the code inside if you tick the ***Enable highlighting in code blocks*** option. This is what happens if you enable it:

![Syntax highlighting example](http://d.pr/i/9HM6+)

I support many popular languages as well as some generic syntax descriptions that can be used if your language of choice is not supported. See [relevant sections on the official site](http://macdown.uranusjr.com/features/) for a full list of supported syntaxes.


### Inline Formatting

The following is a list of optional inline markups supported:

Option name           | Markup           | Result if enabled     |
----------------------|------------------|-----------------------|
Intra-word emphasis   | This\*is\*good   | This<em>is</em>good   |
Strikethrough         | \~~Much wow\~~   | <del>Much wow</del>   |
Underline [^1]        | \_So doge\_      | <u>So doge</u>        |
Quote [^2] [^3]       | "Such editor"    | <q>Such editor</q>    |
Highlight             | \==So good\==    | <mark>So good</mark>  |
Superscript [^4] [^5] | hoge\^(fuga)     | hoge<sup>fuga</sup>   |
Autolink              | http://t.co      | <a href="http://t.co">http://t.co</a> |
Footnotes [^4]        | [\^6] and [\^6]: | [^6] and footnote 6 below |

[^1]: If **Underline** is disabled. _this_ will be the same as *this*.
[^2]: Note that this is different from *blockquote* (a `> `-prefixed block), which is part of the standard Markdown syntax specification.
[^3]: **Quote** and **Smartypants** are syntactically incompatible with each other. The former will take precedence.
[^4]: **Superscript** and **Footnotes** are syntactically incompatible with each other. The former will take precedence.
[^5]: LaTeX `^` superscripts in math will fail if you enabled the **Superscript** extension. You will need to use MathML if you want math support and ***Superscript*** together.
[^6]: This is a footnote.


### Document Formatting

The ***Smartypants*** extension automatically transforms straight quotes (`"` and `'`) in your text into typographer’s quotes (`“`, `”`, `‘`, and `’`) according to the context.[^3] Very useful if you’re a typography freak like I am.


### HTML Rendering

You have already seen how I can highlight your fenced code blocks. See the [Fenced Code Block](#fenced-code-block) section if you haven’t!

I can also render TeX-like math syntaxes, if you allow me to.[^7] I can do inline math like this: \\( 1 + 1 \\) or this (in MathML): <math><mn>1</mn><mo>+</mo><mn>1</mn></math>, and block math:[^5]

\\[
    A^T_S = B
\\]

or (in MathML)

<math display="block">
    <msubsup><mi>A</mi> <mi>S</mi> <mi>T</mi></msubsup>
    <mo>=</mo>
    <mi>B</mi>
</math>


[^7]: Internet connection required.


## Editor Options

You can customize the editor to you liking in the **Editor** preferences pane:

![Editor preferences pane](http://d.pr/i/6OL5+)


### Styling

My editor provides syntax highlighting. You can edit the base font and the coloring/sizing theme. I provided some default themes (courtesy of [Mou](http://mouapp.com)’s creator, Chen Luo) if you don’t know where to start.

You can also edit, or even add new themes if you want to! Just click the ***Reveal*** button, and start moving things around. Remember to use the correct file extension (`.styles`), though. I’m picky about that.

I offer auto-completion and other functions to ease your editing experience. If you don’t like it, however, you can turn them off.


## Hack On

That’s about it. Thanks for listening. I’ll be quiet from now on (unless there’s an update about the app—I’ll remind you for that!).

Happy writing!
