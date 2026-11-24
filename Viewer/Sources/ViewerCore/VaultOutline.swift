import Foundation

/// The sidebar as a flat list of visible rows: a folder shows its children only while it is expanded.
/// A flat list is cheap for SwiftUI to draw even for a vault with thousands of notes, and it lets the
/// whole folder row, not only a small arrow, open and close the folder.
public enum VaultOutline {
    public struct Row: Identifiable, Equatable {
        public let node: VaultNode
        public let depth: Int
        public var id: String { node.id }
    }

    public static func rows(tree: [VaultNode], expanded: Set<String>) -> [Row] {
        var result: [Row] = []
        func walk(_ nodes: [VaultNode], depth: Int) {
            for node in nodes {
                result.append(Row(node: node, depth: depth))
                if node.isFolder, expanded.contains(node.id), let children = node.children { walk(children, depth: depth + 1) }
            }
        }
        walk(tree, depth: 0)
        return result
    }

    /// The folders above a file, outermost first: `A/B/c.md` gives `["A", "A/B"]`.
    /// Opening them reveals the file in the sidebar.
    public static func ancestors(of path: String) -> [String] {
        let parts = path.split(separator: "/").dropLast()
        var result: [String] = []
        var current = ""
        for part in parts {
            current = current.isEmpty ? String(part) : current + "/" + part
            result.append(current)
        }
        return result
    }

    /// The expanded set after a tap on a folder: closed folders open, open folders close.
    public static func toggled(_ id: String, in expanded: Set<String>) -> Set<String> {
        var copy = expanded
        if copy.contains(id) { copy.remove(id) } else { copy.insert(id) }
        return copy
    }

    /// Drops folders that no longer exist (after the vault changed).
    public static func pruned(_ expanded: Set<String>, tree: [VaultNode]) -> Set<String> {
        var existing = Set<String>()
        func walk(_ nodes: [VaultNode]) { for n in nodes where n.isFolder { existing.insert(n.id); walk(n.children ?? []) } }
        walk(tree)
        return expanded.intersection(existing)
    }
}
