# MacDown

![MacDown logo](http://d.pr/i/bEcp+)

Hello there! I’m **MacDown**, the open source Markdown editor for OS X.

Let me introduce myself.


## Markdown and I

**Markdown** is a plain text formatting syntax created by John Gruber, aiming to provide a easy-to-read and feasible markup.

The original Markdown syntax specification can be found [here](http://daringfireball.net/projects/markdown/syntax).

**MacDown** is created as a simple-to-use editor for Markdown documents. I render your Markdown contents real-time into HTML, and display them in a preview panel.

I support all the original Markdown syntaxes. Various non-standard ones can also be turned on/off from the **Markdown** preference pane:

![Markdown preferences pane](http://d.pr/i/hsm4+)

You can also specify extra HTML rendering options through the **Rendering** pane:

![Rendering preferences pane](http://d.pr/i/jA0m+)

### Block Formatting

#### Table

This is a table:

First Header  | Second Header
------------- | -------------
Content Cell  | Content Cell
Content Cell  | Content Cell

You can align cell contents with syntax like this:

| Left-Aligned  | Center Aligned  | Right Aligned |
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

You can also use waves (`~`) instead of backticks (`` ` ``):

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

Currently I support the follwing laguages:

* Bash
* C-like (C, C++, C#, and other similar languages)
* CoffeeScript
* CSS
* Gherken
* Go
* Groovy
* HTTP
* Java
* JavaScript
* Markup (*ML languages such as XML, HTML, etc.)
* NSIS
* PHP
* Python
* Rip
* Ruby
* Sass (Scss)
* Scala
* SQL
* Swift


### Inline Formatting

The following is a list of optional inline markups supported:

Option name         | Markup        | Result if enabled     |
--------------------|---------------|-----------------------|
Intra-word emphasis | This*is*good  | This<em>is</em>good   |
Strikethrough       | ~~Much wow~~  | <del>Much wow</del>   |
Underline [^1]      | _So doge_     | <u>So doge</u>        |
Quote [^2] [^3]     | "Such editor" | <q>Such editor</q>    |
Highlight           | ==So good==   | <mark>So good</mark>  |
Superscript [^4] [^5] | hoge^(fuga) | hoge<sup>fuga</sup>   |
Autolink            | http://t.co   | <a href="http://t.co">http://t.co</a> |
Footnotes [^4]      | [^id] and [^id]: | As shown used in this table. |

[^1]: If ***Underline*** is disabled. _this_ will be the same as *this*.
[^2]: Note that this is different from *blockquote* (a `> `-prefixed block), which is part of the standard Markdown syntax specification.
[^3]: ***Quote*** and ***Smartypants*** are syntactically incompatible with each other. The former will take precedence.
[^4]: ***Superscript*** and ***Footnotes*** are syntactically incompatible with each other. The former will take precedence.
[^5]: LaTeX `^` superscripts in math will fail if you enabled the ***Superscript*** extension. You will need to use MathML if you want math support and ***Superscript*** together.


### Document Formatting

The ***Smartypants*** extension automatically transforms stright quotes (`"` and `'`) in your text into typographer’s quotes (`“`, `”`, `‘`, and `’`) according to the context.[^3] Very useful if you’re a typography freak like I am.


### HTML Rendering

You have already seen how I can highlight your fenced code blocks. See the [Fenced Code Block](#fenced-code-block) section if you haven’t!

I can also render TeX-like math syntaxes, if you allow me to.[^6] I can do inline math like this: \\( 1 + 1 \\) or this (in MathML): <math><mn>1</mn><mo>+</mo><mn>1</mn></math>, and block math:[^5]

\\[
    A^T_S = B
\\]

or (in MathML)

<math display="block">
    <msubsup><mi>A</mi> <mi>S</mi> <mi>T</mi></msubsup>
    <mo>=</mo>
    <mi>B</mi>
</math>


[^6]: Internet connection required.


## Editor Options

You can customize the editor to you liking in the **Editor** preferences pane:

![](http://d.pr/i/F5rQ+)


### Styling

My editor provides syntax highlighting. You can edit the base font and the coloring/sizing theme. I provided some default themes (courtesy of [Mou](http://mouapp.com)’s creator, Chen Luo) if you don’t know where to start.

You can also edit, or even add new themes if you want to! Just click the ***Reveal*** button, and start moving things around. Remember to use the correct file extension (`.styles`), though. I’m picky about that.


### Behaviors

I offer auto-completion and other functions to ease your editing experience. If you don’t like it, however, you can turn them off.


## Hack On

That’s about it. Thanks for listening. I’ll be quiet from now on (unless there’s an update about the app—I’ll remind you for that!).

Happy writing!
