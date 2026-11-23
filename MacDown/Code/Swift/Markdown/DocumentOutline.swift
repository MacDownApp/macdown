import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// A heading, for the outline list.
struct OutlineItem: Equatable {
    var level: Int
    var title: String
    /// 1-based line of the heading.
    var line: Int
}

enum DocumentOutline {
    /// Headings of a document, in order. Headings inside code blocks are not
    /// headings, so a line parser would be wrong; this uses the real parser.
    static func headings(in text: String) -> [OutlineItem] {
        cmark_gfm_core_extensions_ensure_registered()
        guard let parser = cmark_parser_new(CMARK_OPT_DEFAULT) else { return [] }
        defer { cmark_parser_free(parser) }
        let bytes = Array(text.utf8)
        bytes.withUnsafeBufferPointer { buffer in
            buffer.baseAddress?.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
                cmark_parser_feed(parser, $0, buffer.count)
            }
        }
        guard let document = cmark_parser_finish(parser), let iterator = cmark_iter_new(document) else { return [] }
        defer { cmark_node_free(document); cmark_iter_free(iterator) }

        var items: [OutlineItem] = []
        var current: (level: Int, line: Int, title: String)?
        while true {
            let event = cmark_iter_next(iterator)
            if event == CMARK_EVENT_DONE { break }
            guard let node = cmark_iter_get_node(iterator) else { continue }
            let type = cmark_node_get_type(node)
            if type == CMARK_NODE_HEADING {
                if event == CMARK_EVENT_ENTER {
                    current = (Int(cmark_node_get_heading_level(node)), Int(cmark_node_get_start_line(node)), "")
                } else if let heading = current {
                    items.append(OutlineItem(level: heading.level,
                                             title: heading.title.trimmingCharacters(in: .whitespaces), line: heading.line))
                    current = nil
                }
            } else if current != nil, event == CMARK_EVENT_ENTER {
                if type == CMARK_NODE_TEXT || type == CMARK_NODE_CODE, let literal = cmark_node_get_literal(node) {
                    current?.title += String(cString: literal)
                } else if type == CMARK_NODE_SOFTBREAK || type == CMARK_NODE_LINEBREAK {
                    current?.title += " "
                }
            }
        }
        return items
    }
}
