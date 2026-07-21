# Contributing to MacDown

Thank you for your interest in contributing to MacDown! This document outlines our guidelines and processes for contributing.

## Getting Started

### Prerequisites

- macOS 10.8 or later
- Xcode (latest version recommended for Apple Silicon support)
- CocoaPods
- For RMarkdown support: R and Rscript
- For LaTeX support: pdflatex (MacTeX or TeX Live)

### Setting Up Development Environment

```bash
# Clone the repository
git clone https://github.com/MacDownApp/macdown.git
cd macdown

# Install dependencies
pod install

# Open the workspace
open MacDown.xcworkspace
```

### Building the Project

```bash
# Build for current architecture
xcodebuild -workspace MacDown.xcworkspace \
  -scheme MacDown \
  -configuration Release \
  build

# Build for Apple Silicon (ARM64)
xcodebuild -workspace MacDown.xcworkspace \
  -scheme MacDown \
  -configuration Release \
  ARCHS=arm64 \
  VALID_ARCHS=arm64 \
  build

# Build for Intel (x86_64)
xcodebuild -workspace MacDown.xcworkspace \
  -scheme MacDown \
  -configuration Release \
  ARCHS=x86_64 \
  VALID_ARCHS=x86_64 \
  build

# Run tests
xcodebuild -workspace MacDown.xcworkspace \
  -scheme MacDown \
  -configuration Debug \
  test
```

## Project Structure

```
MacDown/
├── MacDown/Code/
│   ├── Application/          # App controller and main UI
│   ├── Document/            # Document management and rendering
│   ├── View/                # UI views and controllers
│   ├── Preferences/         # Preferences and settings
│   ├── Utilities/           # Utility classes and helpers
│   ├── Extension/           # Category extensions
│   └── Dependency/          # External dependencies
├── MacDownTests/            # Unit tests
├── .github/
│   ├── workflows/           # GitHub Actions CI/CD
│   ├── RMARKDOWN_LATEX_SUPPORT.md        # RMarkdown & LaTeX user guide
│   ├── RMARKDOWN_LATEX_IMPLEMENTATION.md # Architecture & integration
│   └── APPLE_SILICON_SUPPORT.md          # Apple Silicon support
└── Podfile                  # CocoaPods dependencies
```

## Key Components

### Markdown Rendering
- **MPRenderer**: Converts Markdown to HTML using Hoedown
- **MPEditorView**: Text editor for markdown input
- **MPDocument**: Main document controller (NSDocument subclass)

### RMarkdown Support (New)
- **MPRMarkdownRenderer**: RMarkdown rendering with R code execution
- **MPRMarkdownParser**: Parse code blocks and chunk options
- **MPRCodeExecutor**: Execute R code via Rscript
- See `.github/RMARKDOWN_LATEX_SUPPORT.md` for user guide
- See `.github/RMARKDOWN_LATEX_IMPLEMENTATION.md` for architecture

### LaTeX Support (New)
- **MPLaTeXRenderer**: LaTeX compilation and PDF preview
- **MPLaTeXParser**: Parse document structure and metadata
- **MPLaTeXCompiler**: Execute pdflatex compilation
- See `.github/RMARKDOWN_LATEX_SUPPORT.md` for user guide
- See `.github/RMARKDOWN_LATEX_IMPLEMENTATION.md` for architecture

### Apple Silicon Support (New)
- Universal binary builds for both ARM64 and x86_64
- CI/CD pipeline builds for both architectures
- See `.github/APPLE_SILICON_SUPPORT.md` for details

## Coding Style

All style rules are enforced under all circumstances except for external dependencies.

### Objective-C

#### The 80-column Rule

All code should obey the 80-column rule.

Exception: If a URL in a comment is too long, it can go over the limit. This happens a lot for Apple’s official documentation. Remember, however, that many websites offer alternative, shorter URL forms that are permanent. For example:

* The title slug in StackOverflow (and other StackExchange sites) URLs can be ommitted. The following two are equivalent:

    `http://stackoverflow.com/questions/13155612/how-does-one-eliminate-objective-c-try-catch-blocks-like-this`
    `http://stackoverflow.com/questions/13155612`

* The commit hash in GitHub commit page’s URL can be shortened. The followings are all equivalent:

    `https://github.com/uranusjr/macdown/commit/1612abb9dbd24113751958777a49cffc6767989c`
    `https://github.com/uranusjr/macdown/commit/1612abb9dbd24`
    `https://github.com/uranusjr/macdown/commit/1612abb`

#### Code Blocks

* Braces go in separate lines. ([Allman style](http://en.wikipedia.org/wiki/Indent_style#Allman_style).)
* If only one statement is contained inside the block, omit braces unless...
    * This is part of an if-(else if-)else structure. All brace styles in the same structure should match (i.e. either non or all of them omit braces).

#### Stetements Inside `if`, `while`, etc.

* Prefer implicit boolean conversion when it makes sense.
    * `if (str.length)` is better than `if (str.length != 0)` if you want to know whether a string is empty. 
    * The same applies when checking for an object’s `nil`-ness.
    * If what you want to compare against is *zero as a number*, not emptiness, such as for `NSRange` position, `NSPoint` coordinates, etc., *do* use the `== 0`/`!= 0` expression.

* If statements need to span multiple lines, prefer putting logical operators at the *beginning* of the line.

    Yes:
    ```c
    while (this_is_very_long
           || this_is_also_very_long)
    {
        // ...
    }
    ```

    No:
    ```c
    while (this_is_very_long ||
           this_is_also_very_long)
    {
        // ...
    }
    ```

* If code alignment is ambiguious, add extra indentation.

    Yes:
    ```c
    if (this_is_very_long
            || this_is_also_very_long)
        foo++;
    ```

    No:
    ```c
    if (this_is_very_long
        || this_is_also_very_long)
        foo++;
    ```

    The above is not enforced (but recommended) if braces exist. Useful if you have a hard time fitting the statement into the 80-column constraint.

    Okay:
    ```c
    if (this_is_very_long
        || this_is_very_very_truly_long)
    {
        foo++;
        bar--;
    }
    ```

#### Invisible Characters

Always use *four spaces* instead of tabs for indentation. Trailing whitespaces should be removed. You can turn on the **Automatically trim trailing whitespace** option in Xcode to let it do the job for you.

Try to ensure that there’s a trailing newline in the end of a file. This is not strictly enforced since there are no easy ways to do that (except checking manually), but I’d appriciate the effort.

## Version Control

MacDown uses Git for source control, and is hosted on GitHub.

### Commit Messages

[General rules](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html) apply. If you absolutely need to, the first line of the message *can* go as long as 72 (instead of 50) characters, but it must not exceed it.

Xcode’s commit window does not do a good job indicating whether your commit message is well-formed. I seldom use it personally, but if you do, you can check whether the commit message is good after you push to GitHub—If you see the first line of your commit message getting truncated, it is too long.

### Pull Requests

Please rebase your branch to `master` when you submit the pull request. There can be some nagging bugs when Git tries to merge files that are not code, particularly `.xib` and project files. When in doubt, always consider splitting changes into smaller commits so that you won’t need to re-apply your changes when things break.

Under certain circumstances I may wish you to perform further rebasing and/or squashing *after* you submit your pull request, or even perform them myself instead of merging your commits as-is. Don’t worry—you will always get full credits for your contribution.

## Reporting Issues

### Bug Reports

Please include:
- **Clear, descriptive title**: "RMarkdown R code execution timeout" not "Bug with R"
- **Steps to reproduce**: Exact steps to trigger the issue
- **Expected vs. actual behavior**: What should happen vs. what actually happens
- **Screenshots**: If UI-related
- **Environment**: macOS version, MacDown version, Apple Silicon or Intel
- **For RMarkdown**: R version and relevant packages
- **For LaTeX**: LaTeX distribution and version

### Feature Requests

Please include:
- **Use case**: Why this feature would be useful
- **Expected behavior**: How it should work
- **Examples**: Links to similar features in other editors
- **Priority**: How important this is to you

## Pull Requests

### Branch Strategy

1. Create a feature branch from `master`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Use descriptive branch names:
   - `feature/rmarkdown-improvements`
   - `fix/latex-compilation-error`
   - `docs/update-readme`

### Before Submitting

1. **Ensure your code follows the style guide** (see above)
2. **Add tests** for new functionality
3. **Update documentation** if needed
4. **Rebase to master**: `git rebase master`
5. **Run tests locally**: Ensure all tests pass
6. **Verify both architectures**: Test on Apple Silicon and Intel if possible

### Commit Message Format

Follow these guidelines:
- First line: 50-72 characters, descriptive
- Reference issues: `Fix #123: Description`
- Use imperative mood: "Add feature" not "Added feature"

Examples:
```
Add RMarkdown code block execution with output caching

Fix LaTeX compilation with BibTeX bibliography

Update documentation for Apple Silicon support
```

### What We Look For

✅ **Good PRs**:
- Focused on a single feature or fix
- Clear commit messages
- Tests for new functionality
- Updated documentation
- Follows code style
- Minimal unrelated changes

❌ **Issues We May Ask About**:
- Large PRs with multiple unrelated changes
- No tests for new functionality
- Code that doesn’t follow style guide
- Inconsistent formatting
- Unrelated refactoring mixed with feature

## Testing

### Running Tests Locally

```bash
# Run all tests
xcodebuild -workspace MacDown.xcworkspace \
  -scheme MacDown \
  -configuration Debug \
  test

# Run specific test
xcodebuild -workspace MacDown.xcworkspace \
  -scheme MacDown \
  -configuration Debug \
  test -only-testing:MacDownTests/MPRendererTests
```

### Manual Testing

When submitting changes, test:
- **Markdown files**: Various syntax and features
- **RMarkdown files**: R code execution, chunk options, output caching
- **LaTeX files**: Document compilation, PDF preview, error handling
- **Preferences**: Settings apply correctly
- **File operations**: Open, save, save-as work correctly
- **Both architectures**: Test on Apple Silicon (arm64) and Intel (x86_64) if possible

### CI/CD Pipeline

All pull requests automatically run GitHub Actions:
- Builds on macOS 14 (Apple Silicon arm64)
- Builds on macOS 12 (Intel x86_64)
- Runs test suite on both architectures
- Creates DMG artifacts

Your PR must pass all checks before merging.

## Documentation

### Files to Update

- **README.md**: For major features
- **.github/*.md**: For feature-specific documentation
- **Code comments**: For complex logic
- **CHANGELOG.md**: For release notes

### Documentation Style

- Use clear, concise language
- Include examples for new features
- Link to related documentation
- Use markdown for code blocks
- Include screenshots for UI changes

## Performance Considerations

- Profile code using Xcode’s Instruments
- Avoid blocking the main thread
- Use async operations for long tasks (R execution, LaTeX compilation)
- Implement caching for expensive operations
- Monitor memory usage

## Questions?

- Check existing issues and discussions
- Read documentation in `.github/` directory
- Open a GitHub discussion
- Contact maintainers

## License

By contributing to MacDown, you agree that your contributions will be licensed under the same license as the project.

---

This style guide is maintained by the MacDown team. Please feel free to ask questions or suggest improvements!
