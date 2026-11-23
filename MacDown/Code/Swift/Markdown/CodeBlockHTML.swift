import Foundation

enum HTMLEscape {
    /// Escapes text for element content and attribute values.
    static func escape(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.utf8.count + 16)
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&#39;"
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }
}

/// HTML for a fenced or indented code block, in the form Prism expects:
/// `<div><pre><code class="language-NAME">…</code></pre></div>`.
enum CodeBlockHTML {
    /// - Parameters:
    ///   - info: The fence info string, or empty.
    ///   - code: The code, including its trailing newline.
    ///   - lineNumbers: Adds class `line-numbers` to the `<pre>`.
    ///   - splitInformation: Treat `language:information` as two parts.
    ///   - resolveLanguage: Maps an alias to the Prism name and records it.
    static func html(info: String, code: String, lineNumbers: Bool, splitInformation: Bool,
                     resolveLanguage: (String) -> String) -> String {
        var language = info
        var information = ""
        if splitInformation, let colon = info.firstIndex(of: ":") {
            language = String(info[info.startIndex..<colon])
            information = String(info[info.index(after: colon)...])
        }
        if !language.isEmpty { language = resolveLanguage(language) }

        var out = "<div><pre"
        if lineNumbers { out += " class=\"line-numbers\"" }
        if !information.isEmpty { out += " data-information=\"\(HTMLEscape.escape(information))\"" }
        out += "><code class=\"language-\(language.isEmpty ? "none" : HTMLEscape.escape(language))\">"
        // Drop the last newline so Prism does not add an empty line.
        var body = Substring(code)
        if body.last == "\n" { body = body.dropLast() }
        out += HTMLEscape.escape(String(body))
        out += "</code></pre></div>\n"
        return out
    }
}
