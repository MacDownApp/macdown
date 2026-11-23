import Foundation

/// Fuzzy matching for Quick Open: the query letters must appear in order in the
/// candidate. Better matches score higher.
enum FuzzyMatcher {
    /// Returns a score, or nil if `query` does not match. An empty query matches everything.
    static func score(query: String, candidate: String) -> Int? {
        let q = Array(query.lowercased().unicodeScalars.filter { !CharacterSet.whitespaces.contains($0) })
        guard !q.isEmpty else { return 0 }
        let original = Array(candidate.unicodeScalars)
        let c = Array(candidate.lowercased().unicodeScalars)
        guard c.count == original.count, q.count <= c.count else {
            // Lower-casing changed the length (rare scripts). Fall back to a simple check.
            return candidate.lowercased().contains(query.lowercased()) ? 1 : nil
        }
        let fileNameStart = (candidate.lastIndex(of: "/").map { candidate.distance(from: candidate.startIndex, to: $0) + 1 }) ?? 0

        var score = 0
        var qi = 0
        var previousMatch = -2
        for (i, ch) in c.enumerated() where qi < q.count && ch == q[qi] {
            var points = 1
            if i == previousMatch + 1 { points += 5 }                         // Consecutive letters.
            let isWordStart = i == 0 || "/ _-.".unicodeScalars.contains(original[i - 1])
                || (CharacterSet.lowercaseLetters.contains(original[i - 1]) && CharacterSet.uppercaseLetters.contains(original[i]))
            if isWordStart { points += 4 }
            if i >= fileNameStart { points += 2 }                              // In the file name.
            score += points
            previousMatch = i
            qi += 1
        }
        guard qi == q.count else { return nil }
        // Shorter paths win ties; an exact file name prefix wins big.
        score -= c.count / 8
        let name = String(String.UnicodeScalarView(c[fileNameStart...]))
        if name.hasPrefix(String(String.UnicodeScalarView(q))) { score += 20 }
        return score
    }

    /// The best matches, best first.
    static func rank(query: String, in candidates: [String], limit: Int = 50) -> [String] {
        var scored: [(String, Int)] = []
        for candidate in candidates {
            if let s = score(query: query, candidate: candidate) { scored.append((candidate, s)) }
        }
        scored.sort { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.count < $1.0.count }
        return scored.prefix(limit).map(\.0)
    }
}
