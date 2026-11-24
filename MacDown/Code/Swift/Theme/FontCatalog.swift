import Foundation

/// One file of a font family and how the page should use it.
public struct FontFace: Equatable {
    public var file: String
    public var weight: Int
    public var italic: Bool
    public init(file: String, weight: Int, italic: Bool) { self.file = file; self.weight = weight; self.italic = italic }
}

/// A font the user can choose for reading text or for code.
public struct FontChoice: Identifiable, Equatable {
    /// Stable id, saved in settings.
    public var id: String
    public var displayName: String
    /// CSS `font-family` list, ready to use.
    public var cssFamily: String
    public var isMonospaced: Bool
    /// Files bundled with the app (empty for system fonts).
    public var faces: [FontFace]
    /// The family name used in `@font-face` for bundled fonts.
    public var bundledFamily: String?
    public init(id: String, displayName: String, cssFamily: String, isMonospaced: Bool, faces: [FontFace], bundledFamily: String?) {
        self.id = id; self.displayName = displayName; self.cssFamily = cssFamily
        self.isMonospaced = isMonospaced; self.faces = faces; self.bundledFamily = bundledFamily
    }
}

/// Fonts that ship with the app, or that the system has.
public enum FontCatalog {
    public static let systemSans = FontChoice(id: "system-sans", displayName: "System (SF Pro)", cssFamily: "-apple-system, \"SF Pro Text\", system-ui, sans-serif", isMonospaced: false, faces: [], bundledFamily: nil)
    public static let systemSerif = FontChoice(id: "system-serif", displayName: "Serif (New York)", cssFamily: "ui-serif, \"New York\", Georgia, serif", isMonospaced: false, faces: [], bundledFamily: nil)
    public static let systemRounded = FontChoice(id: "system-rounded", displayName: "Rounded", cssFamily: "ui-rounded, \"SF Pro Rounded\", -apple-system, sans-serif", isMonospaced: false, faces: [], bundledFamily: nil)
    public static let systemMono = FontChoice(id: "system-mono", displayName: "System Mono (SF Mono)", cssFamily: "ui-monospace, \"SF Mono\", Menlo, monospace", isMonospaced: true, faces: [], bundledFamily: nil)

    /// Installed on every Apple device.
    public static let installedBody: [FontChoice] = [
        systemSans, systemSerif, systemRounded,
        FontChoice(id: "georgia", displayName: "Georgia", cssFamily: "Georgia, serif", isMonospaced: false, faces: [], bundledFamily: nil),
        FontChoice(id: "palatino", displayName: "Palatino", cssFamily: "Palatino, \"Palatino Linotype\", serif", isMonospaced: false, faces: [], bundledFamily: nil),
        FontChoice(id: "avenir", displayName: "Avenir Next", cssFamily: "\"Avenir Next\", sans-serif", isMonospaced: false, faces: [], bundledFamily: nil),
        FontChoice(id: "helvetica", displayName: "Helvetica Neue", cssFamily: "\"Helvetica Neue\", Helvetica, sans-serif", isMonospaced: false, faces: [], bundledFamily: nil),
    ]
    public static let installedCode: [FontChoice] = [
        systemMono,
        FontChoice(id: "menlo", displayName: "Menlo", cssFamily: "Menlo, monospace", isMonospaced: true, faces: [], bundledFamily: nil),
        FontChoice(id: "courier", displayName: "Courier New", cssFamily: "\"Courier New\", Courier, monospace", isMonospaced: true, faces: [], bundledFamily: nil),
    ]

    public static let jetBrainsFamily = "MD JetBrains Mono NF"
    public static let cartographFamily = "MD Cartograph CF NF"

    /// The bundled fonts that are really present. A font whose files are missing is simply not offered
    /// (for example Cartograph, which is licensed and not in the repository).
    public static func bundled(files: [String]) -> [FontChoice] {
        var choices: [FontChoice] = []
        let jetBrains = FontFaceParser.faces(from: files, prefix: "JetBrainsMonoNerdFont-")
        let cartograph = FontFaceParser.faces(from: files, prefix: "CartographCFNerdFont-")
        if !jetBrains.isEmpty {
            choices.append(FontChoice(id: "jetbrains-mono-nf", displayName: "JetBrains Mono Nerd Font",
                                      cssFamily: "\"\(jetBrainsFamily)\", ui-monospace, Menlo, monospace",
                                      isMonospaced: true, faces: jetBrains, bundledFamily: jetBrainsFamily))
        }
        if !cartograph.isEmpty {
            // JetBrains' symbols are the fallback for any icon Cartograph lacks.
            let fallback = jetBrains.isEmpty ? "" : "\"\(jetBrainsFamily)\", "
            choices.append(FontChoice(id: "cartograph-cf-nf", displayName: "Cartograph CF Nerd Font",
                                      cssFamily: "\"\(cartographFamily)\", \(fallback)ui-monospace, Menlo, monospace",
                                      isMonospaced: true, faces: cartograph, bundledFamily: cartographFamily))
        }
        return choices
    }

    /// Choices for reading text: the installed ones and the bundled ones.
    public static func bodyChoices(files: [String]) -> [FontChoice] { installedBody + bundled(files: files) }
    /// Choices for code: monospaced fonts first.
    public static func codeChoices(files: [String]) -> [FontChoice] { bundled(files: files) + installedCode }

    public static func choice(id: String, in list: [FontChoice]) -> FontChoice? { list.first { $0.id == id } }

    /// Finds a choice by id or by display name (what a person types in `config.yaml`), ignoring case,
    /// spaces and dashes.
    public static func choice(matching text: String, in list: [FontChoice]) -> FontChoice? {
        func key(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
        let wanted = key(text)
        guard !wanted.isEmpty else { return nil }
        return list.first { key($0.id) == wanted || key($0.displayName) == wanted }
    }
}

/// Works out weight and style from file names such as `Name-BoldItalic.ttf`.
enum FontFaceParser {
    static func faces(from files: [String], prefix: String) -> [FontFace] {
        files.compactMap { file -> FontFace? in
            let lower = file.lowercased()
            guard file.hasPrefix(prefix), lower.hasSuffix(".ttf") || lower.hasSuffix(".otf") || lower.hasSuffix(".woff2") else { return nil }
            let style = String(file.dropFirst(prefix.count)).split(separator: ".").first.map(String.init) ?? ""
            return face(file: file, style: style)
        }
        .sorted { ($0.weight, $0.italic ? 1 : 0, $0.file) < ($1.weight, $1.italic ? 1 : 0, $1.file) }
    }

    static func face(file: String, style: String) -> FontFace? {
        var rest = style.lowercased()
        var italic = false
        for token in ["italic", "oblique"] where rest.hasSuffix(token) {
            italic = true
            rest = String(rest.dropLast(token.count))
        }
        let weights: [(String, Int)] = [("extralight", 200), ("ultralight", 200), ("thin", 100), ("light", 300),
                                        ("regular", 400), ("medium", 500), ("semibold", 600), ("demibold", 600),
                                        ("extrabold", 800), ("ultrabold", 800), ("bold", 700), ("black", 900), ("heavy", 900)]
        if rest.isEmpty { return FontFace(file: file, weight: 400, italic: italic) }
        guard let weight = weights.first(where: { $0.0 == rest })?.1 else { return nil }
        return FontFace(file: file, weight: weight, italic: italic)
    }
}

/// The user's font settings, and the CSS they produce.
public struct FontSettings: Codable, Equatable {
    /// Id of a body font choice, or empty for the default.
    public var bodyID = ""
    public var codeID = ""
    /// A font family typed by hand; wins over the choice. Letters, digits, spaces and dashes only.
    public var customBody = ""
    public var customCode = ""

    public init(bodyID: String = "", codeID: String = "", customBody: String = "", customCode: String = "") {
        self.bodyID = bodyID; self.codeID = codeID; self.customBody = customBody; self.customCode = customCode
    }
}

public enum FontCSS {
    /// A typed font name, made safe to put in CSS (nothing but letters, digits, spaces, dots, dashes).
    public static func sanitize(_ name: String) -> String {
        String(name.filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" || $0 == "." || $0 == "_" })
            .trimmingCharacters(in: .whitespaces)
    }

    /// CSS for the chosen fonts: `@font-face` for bundled ones and `font-family` rules.
    /// - Parameters:
    ///   - files: names of the font files in the app (to know what is available).
    ///   - baseURL: where the page can load those files, with a trailing slash
    ///     (`md://app/Fonts/` or `macdown-file:///path/to/Fonts/`).
    /// Returns "" when nothing is customized, so the base style stays as it is.
    public static func css(settings: FontSettings, files: [String], baseURL: String) -> String {
        let body = resolve(settings.customBody, id: settings.bodyID, list: FontCatalog.bodyChoices(files: files), mono: false)
        let code = resolve(settings.customCode, id: settings.codeID, list: FontCatalog.codeChoices(files: files), mono: true)
        guard body != nil || code != nil else { return "" }

        var out = ""
        var needed: [FontChoice] = []
        for choice in [body?.choice, code?.choice].compactMap({ $0 }) where choice.bundledFamily != nil && !needed.contains(choice) {
            needed.append(choice)
        }
        // Cartograph falls back to JetBrains for icons, so its files must be available too.
        if needed.contains(where: { $0.bundledFamily == FontCatalog.cartographFamily }),
           let jetBrains = FontCatalog.bundled(files: files).first(where: { $0.bundledFamily == FontCatalog.jetBrainsFamily }),
           !needed.contains(jetBrains) {
            needed.append(jetBrains)
        }
        for choice in needed {
            for face in choice.faces {
                let file = face.file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? face.file
                let format = face.file.lowercased().hasSuffix("woff2") ? "woff2" : (face.file.lowercased().hasSuffix("otf") ? "opentype" : "truetype")
                out += "@font-face { font-family: \"\(choice.bundledFamily!)\"; src: url(\"\(baseURL)\(file)\") format(\"\(format)\"); font-weight: \(face.weight); font-style: \(face.italic ? "italic" : "normal"); font-display: swap; }\n"
            }
        }
        // More specific than the base styles and Prism's own `code[class*=language-]` font rule.
        if let body = body { out += "html body { font-family: \(body.family); }\n" }
        if let code = code {
            out += "html body code, html body pre, html body kbd, html body samp, html body tt, html body code[class*=\"language-\"], html body pre[class*=\"language-\"] { font-family: \(code.family); }\n"
        }
        return out
    }

    private struct Resolved { var family: String; var choice: FontChoice? }

    private static func resolve(_ custom: String, id: String, list: [FontChoice], mono: Bool) -> Resolved? {
        let typed = sanitize(custom)
        if !typed.isEmpty {
            return Resolved(family: "\"\(typed)\", " + (mono ? FontCatalog.systemMono.cssFamily : FontCatalog.systemSans.cssFamily), choice: nil)
        }
        guard !id.isEmpty, let choice = FontCatalog.choice(id: id, in: list) else { return nil }
        // The system defaults need no rule: that is what the base style already uses.
        if choice.id == FontCatalog.systemSans.id || choice.id == FontCatalog.systemMono.id { return nil }
        return Resolved(family: choice.cssFamily, choice: choice)
    }

    /// For `config.yaml`, where a font is given by name: a known choice, or else a typed family.
    public static func settings(bodyName: String?, codeName: String?, files: [String]) -> FontSettings {
        var settings = FontSettings()
        if let name = bodyName, !name.isEmpty {
            if let choice = FontCatalog.choice(matching: name, in: FontCatalog.bodyChoices(files: files)) { settings.bodyID = choice.id }
            else { settings.customBody = name }
        }
        if let name = codeName, !name.isEmpty {
            if let choice = FontCatalog.choice(matching: name, in: FontCatalog.codeChoices(files: files)) { settings.codeID = choice.id }
            else { settings.customCode = name }
        }
        return settings
    }
}
