import Foundation

enum GitChangeKind: Equatable {
    case modified, added, deleted, renamed, copied, typeChanged, untracked, conflicted, ignored
}

/// A file with changes, as `git status` reports it.
struct GitStatusEntry: Equatable {
    /// Path relative to the repository root.
    var path: String
    /// Old path, for renames and copies.
    var originalPath: String?
    /// Change that is staged (index vs HEAD). Nil if none.
    var staged: GitChangeKind?
    /// Change in the working tree (files vs index). Nil if none.
    var unstaged: GitChangeKind?

    var isUntracked: Bool { unstaged == .untracked }
    var isConflicted: Bool { unstaged == .conflicted }
}

struct GitStatus: Equatable {
    var branch: String?          // Nil when HEAD is detached.
    var commit: String?          // Full id of HEAD; nil before the first commit.
    var upstream: String?
    var ahead = 0
    var behind = 0
    var entries: [GitStatusEntry] = []

    var isClean: Bool { entries.isEmpty }
}

/// One block of changed lines.
struct GitHunk: Equatable {
    var oldStart: Int, oldCount: Int
    var newStart: Int, newCount: Int
    /// The `@@ … @@` line and the lines after it, as printed by git.
    var patchText: String
}

/// A marker for the editor gutter.
struct GutterChange: Equatable {
    enum Kind { case added, modified, removed }
    var kind: Kind
    /// 1-based lines in the current text. For `.removed`, the single line after
    /// which text was deleted (0 means the top of the file).
    var lines: ClosedRange<Int>
}

struct GitBranch: Equatable {
    var name: String
    var isCurrent: Bool
}

// MARK: - Parsing

enum GitParser {
    /// Parses `git status --porcelain=v2 -z --branch`.
    static func parseStatus(_ data: Data) -> GitStatus {
        var status = GitStatus()
        let fields = data.split(separator: 0, omittingEmptySubsequences: true)
            .map { String(decoding: $0, as: UTF8.self) }
        var i = 0
        while i < fields.count {
            let record = fields[i]
            i += 1
            if record.hasPrefix("# ") {
                let parts = record.dropFirst(2).split(separator: " ", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { continue }
                switch parts[0] {
                case "branch.oid": status.commit = parts[1] == "(initial)" ? nil : parts[1]
                case "branch.head": status.branch = parts[1] == "(detached)" ? nil : parts[1]
                case "branch.upstream": status.upstream = parts[1]
                case "branch.ab":
                    let ab = parts[1].split(separator: " ")
                    if ab.count == 2 { status.ahead = Int(ab[0].dropFirst()) ?? 0; status.behind = Int(ab[1].dropFirst()) ?? 0 }
                default: break
                }
            } else if record.hasPrefix("1 ") {
                // 1 XY sub mH mI mW hH hI path
                let p = record.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: false)
                guard p.count == 9 else { continue }
                status.entries.append(entry(xy: String(p[1]), path: String(p[8]), original: nil))
            } else if record.hasPrefix("2 ") {
                // 2 XY sub mH mI mW hH hI Xscore path <NUL> origPath
                let p = record.split(separator: " ", maxSplits: 9, omittingEmptySubsequences: false)
                guard p.count == 10 else { continue }
                let original = i < fields.count ? fields[i] : nil
                i += 1
                status.entries.append(entry(xy: String(p[1]), path: String(p[9]), original: original))
            } else if record.hasPrefix("u ") {
                // u XY sub m1 m2 m3 mW h1 h2 h3 path
                let p = record.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: false)
                guard p.count == 11 else { continue }
                status.entries.append(GitStatusEntry(path: String(p[10]), staged: nil, unstaged: .conflicted))
            } else if record.hasPrefix("? ") {
                status.entries.append(GitStatusEntry(path: String(record.dropFirst(2)), staged: nil, unstaged: .untracked))
            }
        }
        return status
    }

    private static func entry(xy: String, path: String, original: String?) -> GitStatusEntry {
        let chars = Array(xy)
        return GitStatusEntry(path: path, originalPath: original,
                              staged: kind(chars[0]), unstaged: chars.count > 1 ? kind(chars[1]) : nil)
    }

    private static func kind(_ c: Character) -> GitChangeKind? {
        switch c {
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        case "T": return .typeChanged
        case "U": return .conflicted
        default: return nil
        }
    }

    /// Parses unified diff output (one file) into hunks.
    static func parseHunks(_ diff: String) -> [GitHunk] {
        var hunks: [GitHunk] = []
        var current: (header: (Int, Int, Int, Int), lines: [String])?
        func flush() {
            if let c = current {
                hunks.append(GitHunk(oldStart: c.header.0, oldCount: c.header.1,
                                     newStart: c.header.2, newCount: c.header.3,
                                     patchText: c.lines.joined(separator: "\n") + "\n"))
            }
        }
        for line in diff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("@@"), let header = parseHunkHeader(line) {
                flush()
                current = (header, [line])
            } else if current != nil, !line.hasPrefix("diff ") {
                current?.lines.append(line)
            }
        }
        flush()
        // A trailing empty element from the final newline.
        return hunks.map { hunk in
            var h = hunk
            while h.patchText.hasSuffix("\n\n") { h.patchText.removeLast() }
            return h
        }
    }

    /// `@@ -a,b +c,d @@` (counts are optional and mean 1).
    static func parseHunkHeader(_ line: String) -> (Int, Int, Int, Int)? {
        let parts = line.split(separator: " ")
        guard parts.count >= 3, parts[0] == "@@", parts[1].hasPrefix("-"), parts[2].hasPrefix("+") else { return nil }
        func pair(_ s: Substring) -> (Int, Int)? {
            let nums = s.dropFirst().split(separator: ",", omittingEmptySubsequences: false)
            guard let start = Int(nums[0]) else { return nil }
            return (start, nums.count > 1 ? (Int(nums[1]) ?? 1) : 1)
        }
        guard let old = pair(parts[1]), let new = pair(parts[2]) else { return nil }
        return (old.0, old.1, new.0, new.1)
    }

    /// Gutter markers for a list of hunks.
    static func gutterChanges(_ hunks: [GitHunk]) -> [GutterChange] {
        hunks.map { h in
            if h.oldCount == 0 {
                return GutterChange(kind: .added, lines: h.newStart...(h.newStart + max(h.newCount, 1) - 1))
            } else if h.newCount == 0 {
                return GutterChange(kind: .removed, lines: h.newStart...h.newStart)
            } else {
                return GutterChange(kind: .modified, lines: h.newStart...(h.newStart + h.newCount - 1))
            }
        }
    }
}
