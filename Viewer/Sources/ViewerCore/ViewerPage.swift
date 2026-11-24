import Foundation

/// Builds the complete HTML page for a rendered note.
public enum ViewerPage {
    /// - Parameters:
    ///   - themeCSS: from `ViewerTheme.css(systemDark:)`; comes after the base style, so it wins.
    ///   - note: the rendered note. Math, diagrams and code highlighting are loaded only if it needs them.
    ///   - fontCSS: from `FontStore`; after the theme, so the user's fonts win.
    ///   - accentCSS: from `AccentCSS.css(hex:)`; last, so the user's accent wins over the theme's link color.
    ///   - scrollTo: heading text to scroll to after the page loads (from `[[Note#Heading]]`).
    public static func html(note: RenderedNote, title: String, themeCSS: String, fontCSS: String = "", accentCSS: String = "", scrollTo: String? = nil) -> String {
        var scripts = ""
        if note.usesMath { scripts += "<script src=\"md://app/KaTeX/katex-init.js\"></script>\n" }
        if note.usesMermaid {
            scripts += "<script src=\"md://app/Diagrams/diagram-common.js\"></script>\n"
            scripts += "<script src=\"md://app/Diagrams/mermaid-init.js\"></script>\n"
        }
        if note.usesCode {
            scripts += "<script>window.Prism = window.Prism || {}; Prism.manual = false;</script>\n"
            scripts += "<script src=\"md://app/components/prism-core.min.js\"></script>\n"
            scripts += "<script src=\"md://app/prism-autoloader.min.js\"></script>\n"
            scripts += "<script>Prism.plugins.autoloader.languages_path = 'md://app/components/';</script>\n"
        }
        scripts += "<script>\(support(scrollTo: scrollTo))</script>\n"

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <title>\(HTMLEscape.escape(title))</title>
        <style>\(baseCSS)</style>
        <style>\(themeCSS)</style>
        <style>\(fontCSS)</style>
        <style>\(accentCSS)</style>
        </head>
        <body>
        <article class="note">
        \(note.bodyHTML)
        </article>
        \(scripts)</body>
        </html>
        """
    }

    /// Scrolls to a heading by its text, and lets task checkboxes stay read-only.
    private static func support(scrollTo: String?) -> String {
        let target = scrollTo.map { "\"" + $0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "<", with: "\\u003c") + "\"" } ?? "null"
        return """
        (function () {
          function norm(s) { return (s || '').toLowerCase().replace(/[^\\p{L}\\p{N}]+/gu, ' ').trim(); }
          window.scrollToHeading = function (text) {
            var want = norm(text);
            var hs = document.querySelectorAll('h1,h2,h3,h4,h5,h6');
            for (var i = 0; i < hs.length; i++) {
              if (norm(hs[i].textContent) === want) { hs[i].scrollIntoView(); return true; }
            }
            return false;
          };
          var target = \(target);
          if (target) { window.addEventListener('load', function () { setTimeout(function () { window.scrollToHeading(target); }, 50); }); }
          document.querySelectorAll('input[type=checkbox]').forEach(function (c) { c.disabled = true; });
        })();
        """
    }

    // MARK: Base style

    /// Reading style for an iPad: a comfortable column, system fonts, and the Obsidian elements.
    static let baseCSS = """
    :root { color-scheme: light dark; }
    html { -webkit-text-size-adjust: 100%; }
    body { margin: 0; font: 17px/1.65 -apple-system, "SF Pro Text", system-ui, sans-serif; overflow-wrap: break-word; }
    .note { max-width: 46rem; margin: 0 auto; padding: 1.5rem 1.25rem 4rem; }
    h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.6em 0 0.5em; font-weight: 650; }
    h1 { font-size: 2em; } h2 { font-size: 1.55em; } h3 { font-size: 1.3em; } h4 { font-size: 1.1em; }
    h1:first-child, h2:first-child { margin-top: 0.2em; }
    p, ul, ol, table, pre, blockquote, details { margin: 0.9em 0; }
    ul, ol { padding-left: 1.6em; }
    li > ul, li > ol { margin: 0.2em 0; }
    ul > li:has(> input[type=checkbox]) { list-style: none; margin-left: -1.3em; }
    input[type=checkbox] { margin-right: 0.5em; transform: scale(1.15); }
    a { text-decoration: none; }
    a:hover { text-decoration: underline; }
    img, video { max-width: 100%; height: auto; border-radius: 4px; }
    audio { width: 100%; }
    hr { border: 0; border-top: 1px solid rgba(128,128,128,0.35); margin: 2em 0; }
    blockquote { padding: 0.1em 1em; border-left: 3px solid rgba(128,128,128,0.5); }
    table { border-collapse: collapse; display: block; overflow-x: auto; max-width: 100%; }
    th, td { border: 1px solid rgba(128,128,128,0.35); padding: 0.4em 0.8em; }
    th { font-weight: 650; background: rgba(128,128,128,0.1); }
    code { font: 0.88em ui-monospace, "SF Mono", Menlo, monospace; }
    :not(pre) > code { background: rgba(128,128,128,0.16); padding: 0.12em 0.35em; border-radius: 4px; }
    pre { padding: 0.9em 1em; border-radius: 8px; overflow-x: auto; -webkit-overflow-scrolling: touch; }
    pre code { background: none; padding: 0; font-size: 0.85em; line-height: 1.5; white-space: pre; }
    mark { background: rgba(255, 208, 0, 0.4); color: inherit; padding: 0 0.15em; border-radius: 3px; }
    .footnotes { font-size: 0.9em; opacity: 0.85; border-top: 1px solid rgba(128,128,128,0.35); margin-top: 2.5em; }
    .katex-display { overflow-x: auto; overflow-y: hidden; padding: 0.2em 0; }
    /* Obsidian */
    .wikilink { color: #7c5cd6; }
    .wikilink.unresolved { opacity: 0.55; text-decoration: underline dotted; }
    .tag { background: rgba(124, 92, 214, 0.18); color: #7c5cd6; padding: 0.05em 0.5em; border-radius: 1em; font-size: 0.9em; }
    a.pdf-embed { display: flex; align-items: center; gap: 0.8em; margin: 0.8em 0; padding: 0.7em 1em; border-radius: 10px; border: 1px solid rgba(128,128,128,0.35); background: rgba(128,128,128,0.08); color: inherit; text-decoration: none; }
    .pdf-badge { background: #d9372b; color: #fff; font: 700 0.7em/1 -apple-system, sans-serif; padding: 0.45em 0.5em; border-radius: 4px; letter-spacing: 0.04em; }
    .pdf-name { flex: 1; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .pdf-hint { font-size: 0.8em; opacity: 0.6; }
    .embed-note { border-left: 3px solid rgba(124, 92, 214, 0.6); padding: 0 1em; margin: 1em 0; background: rgba(128,128,128,0.06); border-radius: 0 6px 6px 0; }
    .embed-title { font-size: 0.8em; opacity: 0.7; margin-top: 0.6em; }
    details.properties { font-size: 0.9em; border: 1px solid rgba(128,128,128,0.3); border-radius: 8px; padding: 0.3em 0.9em; }
    details.properties summary { cursor: pointer; opacity: 0.75; }
    details.properties table { display: table; margin: 0.4em 0; }
    details.properties th { background: none; text-align: left; font-weight: 600; white-space: nowrap; }
    .callout { --c: 68, 138, 255; margin: 1em 0; border-radius: 8px; border-left: 4px solid rgb(var(--c)); background: rgba(var(--c), 0.1); padding: 0.1em 1em 0.1em; }
    .callout-title { display: flex; gap: 0.6em; align-items: center; font-weight: 650; color: rgb(var(--c)); padding: 0.6em 0 0.3em; }
    summary.callout-title { cursor: pointer; }
    .callout-icon { width: 1.2em; text-align: center; }
    .callout-content > :first-child { margin-top: 0.2em; } .callout-content > :last-child { margin-bottom: 0.7em; }
    .callout[data-callout=abstract], .callout[data-callout=tip] { --c: 0, 191, 188; }
    .callout[data-callout=success] { --c: 8, 185, 78; }
    .callout[data-callout=question] { --c: 224, 172, 0; }
    .callout[data-callout=warning] { --c: 236, 117, 0; }
    .callout[data-callout=failure], .callout[data-callout=danger], .callout[data-callout=bug] { --c: 233, 49, 71; }
    .callout[data-callout=example] { --c: 120, 82, 238; }
    .callout[data-callout=quote] { --c: 158, 158, 158; }
    .macdown-diagram { text-align: center; margin: 1.2em 0; overflow-x: auto; }
    .macdown-diagram svg { max-width: 100%; height: auto; }
    .macdown-diagram-error { color: #cc0000; font-size: 0.8em; white-space: pre-wrap; margin: -0.5em 0 1em; }
    """
}
