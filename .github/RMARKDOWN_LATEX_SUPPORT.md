# RMarkdown and LaTeX Support in MacDown

MacDown now fully supports **RMarkdown (.rmd)** and **LaTeX (.tex)** documents with live preview, syntax highlighting, and full compilation support.

## Features

### RMarkdown Support

**What is RMarkdown?**
RMarkdown is a format that combines R code with markdown text. It allows you to:
- Write narrative text in markdown
- Embed executable R code blocks
- Generate dynamic reports with R output automatically integrated

**Key Features:**
- ✅ Full RMarkdown syntax support (.rmd, .Rmd, .rmarkdown)
- ✅ R code block execution with ````{r}` syntax
- ✅ Automatic output capture and display
- ✅ Cache R outputs to avoid re-computation
- ✅ Syntax highlighting for R code
- ✅ Live preview with R code results
- ✅ Support for chunk options (e.g., `echo=FALSE`, `results='hide'`)

**Requirements:**
- R installed (detected from common installation paths)
- Rscript executable available in PATH

### LaTeX Support

**What is LaTeX?**
LaTeX is a document preparation system that's perfect for:
- Scientific and technical documents
- Complex mathematical equations
- Professional typesetting
- Academic papers and theses

**Key Features:**
- ✅ Full LaTeX document support (.tex, .latex)
- ✅ Automatic pdflatex compilation
- ✅ PDF preview in editor
- ✅ Real-time compilation on edit
- ✅ Syntax highlighting for LaTeX commands
- ✅ Error reporting with compilation log
- ✅ Support for BibTeX bibliography
- ✅ Multi-pass compilation for references

**Requirements:**
- LaTeX distribution installed (MacTeX, TeX Live, or similar)
- pdflatex command available in PATH

## Getting Started

### RMarkdown Files

1. **Create a new RMarkdown file**: File → New or save with `.rmd` extension

2. **Basic structure**:
   ```markdown
   # My R Analysis

   Here's some narrative text explaining the analysis.

   ```{r}
   # This is R code
   x <- 1:10
   mean(x)
   ```

   The mean of 1-10 is calculated above.
   ```

3. **View live preview**: The preview pane shows markdown text + R output

4. **Chunk options**:
   ```markdown
   ```{r, echo=FALSE, results='hide'}
   # This code won't be shown, output hidden
   ```

   ```{r, fig.width=10}
   # This code creates a wider figure
   plot(cars)
   ```
   ```

### LaTeX Files

1. **Create a new LaTeX file**: File → New or save with `.tex` extension

2. **Basic structure**:
   ```latex
   \documentclass{article}
   \title{My Document}
   \author{Your Name}

   \begin{document}
   \maketitle

   \section{Introduction}
   This is my LaTeX document.

   \end{document}
   ```

3. **View live preview**: The preview pane shows compiled PDF

4. **Using packages**:
   ```latex
   \documentclass{article}
   \usepackage{amsmath}
   \usepackage{graphicx}

   \begin{document}
   ...
   \end{document}
   ```

## Preferences

### RMarkdown Preferences

Access via MacDown → Preferences → RMarkdown

- **Execute code on edit**: Auto-run R code when editing (default: enabled)
- **Execution timeout**: Maximum seconds to wait for R code (default: 30s)
- **Show chunk output**: Display R code output in preview (default: enabled)
- **Working directory**: Directory where R code executes

### LaTeX Preferences

Access via MacDown → Preferences → LaTeX

- **Compile on edit**: Auto-compile when editing (default: enabled)
- **LaTeX engine**: Choose pdflatex, xelatex, or lualatex
- **Show build log**: Display compilation log on error (default: enabled)
- **Use BibTeX**: Auto-run BibTeX for bibliography
- **Embedded PDF viewer**: Show PDF directly in preview (default: enabled)

## Caching

### RMarkdown Caching

RMarkdown caches R output to avoid re-running expensive computations:

- **Location**: `~/.macdown/rmd_cache/{document_hash}/`
- **What's cached**: Output of each R code chunk
- **Cache invalidation**: Automatically cleared when R code changes
- **Manual clear**: Delete cache folder to force re-run all chunks

### LaTeX Caching

LaTeX compilation results are cached:

- **Location**: `~/.macdown/latex_cache/{document_hash}/`
- **What's cached**: Compiled PDF file
- **Cache invalidation**: Cleared when source changes
- **Build log**: Stored for debugging failed compilations

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Toggle preview | Cmd+Shift+I |
| Export as PDF | Cmd+Shift+E |
| Show compilation error | Cmd+Shift+L |

## Export Options

### RMarkdown Export

- **HTML with inline output**: All R output embedded in HTML
- **PDF via LaTeX**: Convert to PDF (requires LaTeX)
- **R script**: Extract only R code blocks
- **Markdown**: Remove R code, keep markdown only

### LaTeX Export

- **PDF**: Compiled PDF file
- **Source with paths**: LaTeX source with full asset paths
- **Processed**: LaTeX with includes resolved

## Troubleshooting

### RMarkdown

**"R is not installed" error**
- Install R from https://www.r-project.org/
- MacDown will auto-detect after installation
- Verify in Preferences → RMarkdown

**Code execution times out**
- Increase timeout in Preferences → RMarkdown → Execution timeout
- Check for infinite loops in R code
- Use small dataset for testing

**Cache issues**
- Delete `~/.macdown/rmd_cache/` to clear all caches
- Or delete specific document cache folder

### LaTeX

**"pdflatex is not installed" error**
- Install MacTeX: https://www.tug.org/mactex/
- Or TeX Live: https://www.tug.org/texlive/
- MacDown will auto-detect after installation

**"Package not found" error**
- Missing LaTeX packages need to be installed
- With MacTeX: `sudo tlmgr install {package_name}`
- With TeX Live: `tlmgr install {package_name}`

**Compilation fails with cryptic error**
- Enable "Show build log" in Preferences
- Error messages are shown in preview pane
- Check `/var/log/pdflatex.log` for detailed logs

**PDF doesn't update**
- Try toggling preview: Cmd+Shift+I
- Clear cache: Delete `~/.macdown/latex_cache/`
- Save document: Cmd+S

## Examples

### RMarkdown Example

```rmarkdown
---
title: "Data Analysis Report"
date: 2024-01-15
---

# Analysis of mtcars Dataset

Let's analyze the built-in mtcars dataset in R.

## Summary Statistics

```{r, echo=FALSE}
summary(mtcars)
```

## Visualization

```{r, fig.width=8, fig.height=6}
plot(mtcars$wt, mtcars$mpg,
     main="Weight vs Fuel Efficiency",
     xlab="Weight (1000 lbs)",
     ylab="Miles per Gallon")
```

The plot shows a negative correlation between weight and fuel efficiency.

```{r}
cor(mtcars$wt, mtcars$mpg)
```
```

### LaTeX Example

```latex
\documentclass{article}
\usepackage{amsmath}

\title{Introduction to LaTeX}
\author{MacDown User}

\begin{document}

\maketitle

\section{Equations}

Here's an inline equation: $E = mc^2$.

Here's a displayed equation:
\[
\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
\]

\section{Lists}

\begin{enumerate}
\item First item
\item Second item
\item Third item
\end{enumerate}

\end{document}
```

## Architecture

MacDown handles RMarkdown and LaTeX through:

1. **File Type Detection**: Automatically detects file type from extension
2. **Dedicated Renderers**: Separate rendering pipelines for each format
3. **External Tool Integration**: Uses system R and pdflatex installations
4. **Smart Caching**: Avoids redundant compilation/execution
5. **Unified UI**: Same editor/preview interface for all formats

## Future Enhancements

- Support for more LaTeX engines (XeLaTeX, LuaLaTeX)
- RMarkdown inline R evaluation
- Pandoc integration for more export formats
- Git-aware diffing for LaTeX documents
- Collaborative editing support
- Package management for LaTeX

## Support

For issues or feature requests:
- GitHub: https://github.com/MacDownApp/macdown/issues
- Email: support@macdownapp.com

## License

RMarkdown and LaTeX support for MacDown are part of the main project and subject to the same license.
