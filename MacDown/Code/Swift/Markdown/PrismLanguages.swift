import Foundation

/// Knows which Prism language components a set of code blocks needs.
/// Aliases (`js` -> `javascript`) come from `syntax_highlighting.json`;
/// dependencies (`cpp` needs `c`) come from Prism's `components.js`.
/// Removed together with Prism in Phase 3.
final class PrismLanguages {
    static let shared = PrismLanguages()

    private let aliases: [String: String]
    private let languages: [String: Any]

    init(bundle: Bundle = .main) {
        var aliasMap: [String: String] = [:]
        if let url = bundle.url(forResource: "syntax_highlighting", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let found = json["aliases"] as? [String: String] {
            aliasMap = found
        }
        aliases = aliasMap

        var map: [String: Any] = [:]
        if let url = bundle.url(forResource: "components", withExtension: "js", subdirectory: "Prism"),
           let code = try? String(contentsOf: url, encoding: .utf8),
           let components = MPGetObjectFromJavaScript(code, "components") as? [String: Any],
           let found = components["languages"] as? [String: Any] {
            map = found
        }
        languages = map
    }

    /// Returns the Prism name for `language` and adds it, and what it needs,
    /// to `list`. A language moves to the front, so dependencies load first.
    func resolve(_ language: String, into list: inout [String]) -> String {
        let name = aliases[language] ?? language
        add(name, to: &list)
        return name
    }

    private func add(_ language: String, to list: inout [String], depth: Int = 0) {
        guard depth < 16 else { return }   // Guards against cyclic data.
        if let index = list.firstIndex(of: language) { list.remove(at: index) }
        list.insert(language, at: 0)

        guard let info = languages[language] as? [String: Any] else { return }
        if let one = info["require"] as? String {
            add(one, to: &list, depth: depth + 1)
        } else if let many = info["require"] as? [String] {
            for name in many { add(name, to: &list, depth: depth + 1) }
        }
    }
}
