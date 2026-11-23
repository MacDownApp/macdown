import Foundation

/// Builds the nested `<ul class="toc">` list that replaces a `[TOC]` line.
///
/// The markup is the one the earlier Hoedown based renderer produced, so existing
/// styles keep working: the outermost list has class `toc`, every entry is
/// `<li>` followed by a link to `#toc_N`.
enum TableOfContents {
    struct Entry: Equatable {
        var level: Int
        /// Inline HTML of the heading.
        var html: String
        /// Number used in the heading id (`toc_N`) and the link.
        var index: Int
    }

    static func html(for entries: [Entry]) -> String {
        guard !entries.isEmpty else { return "" }
        var out = ""
        var current = 0
        let offset = entries[0].level - 1

        for entry in entries {
            let level = entry.level - offset
            if level > current {
                while level > current {
                    out += current == 0 ? "<ul class=\"toc\">\n<li>\n" : "<ul>\n<li>\n"
                    current += 1
                }
            } else if level < current {
                out += "</li>\n"
                while level < current {
                    out += "</ul>\n</li>\n"
                    current -= 1
                }
                out += "<li>\n"
            } else {
                out += "</li>\n<li>\n"
            }
            out += "<a href=\"#toc_\(entry.index)\">\(entry.html)</a>\n"
        }
        while current > 0 {
            out += "</li>\n</ul>\n"
            current -= 1
        }
        return out
    }
}
