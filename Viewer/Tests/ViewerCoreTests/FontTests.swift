import XCTest
@testable import ViewerCore

final class FontTests: XCTestCase {
    private let jetBrains = ["JetBrainsMonoNerdFont-Regular.ttf", "JetBrainsMonoNerdFont-Bold.ttf",
                             "JetBrainsMonoNerdFont-Italic.ttf", "JetBrainsMonoNerdFont-BoldItalic.ttf", "JetBrainsMono-OFL.txt"]
    private let cartograph = ["CartographCFNerdFont-Regular.ttf", "CartographCFNerdFont-Thin.ttf", "CartographCFNerdFont-ThinItalic.ttf",
                              "CartographCFNerdFont-BoldItalic.ttf"]
    private let base = "md://app/Fonts/"

    func testFileNamesBecomeWeightsAndStyles() {
        let faces = FontFaceParser.faces(from: jetBrains, prefix: "JetBrainsMonoNerdFont-")
        XCTAssertEqual(faces.map { "\($0.weight)\($0.italic ? "i" : "")" }, ["400", "400i", "700", "700i"])
        XCTAssertEqual(FontFaceParser.face(file: "x", style: "ThinItalic"), FontFace(file: "x", weight: 100, italic: true))
        XCTAssertEqual(FontFaceParser.face(file: "x", style: "SemiBold")?.weight, 600)
        XCTAssertEqual(FontFaceParser.face(file: "x", style: "ExtraBoldItalic"), FontFace(file: "x", weight: 800, italic: true))
        XCTAssertEqual(FontFaceParser.face(file: "x", style: "Italic"), FontFace(file: "x", weight: 400, italic: true))
        XCTAssertNil(FontFaceParser.face(file: "x", style: "Mystery"))
        XCTAssertTrue(FontFaceParser.faces(from: ["Other-Regular.ttf", "notes.txt"], prefix: "JetBrainsMonoNerdFont-").isEmpty)
    }

    func testOnlyFontsThatArePresentAreOffered() {
        XCTAssertEqual(FontCatalog.bundled(files: jetBrains).map(\.displayName), ["JetBrains Mono Nerd Font"])
        XCTAssertEqual(FontCatalog.bundled(files: jetBrains + cartograph).map(\.displayName),
                       ["JetBrains Mono Nerd Font", "Cartograph CF Nerd Font"])
        XCTAssertEqual(FontCatalog.bundled(files: cartograph).map(\.displayName), ["Cartograph CF Nerd Font"])
        XCTAssertTrue(FontCatalog.bundled(files: []).isEmpty, "A clone without the licensed font just does not offer it")
        XCTAssertEqual(FontCatalog.codeChoices(files: jetBrains).first?.id, "jetbrains-mono-nf", "Code fonts: bundled first")
        XCTAssertTrue(FontCatalog.bodyChoices(files: []).contains { $0.id == "system-serif" })
    }

    func testNothingCustomizedMeansNoCSS() {
        XCTAssertEqual(FontCSS.css(settings: FontSettings(), files: jetBrains, baseURL: base), "")
        XCTAssertEqual(FontCSS.css(settings: FontSettings(bodyID: "system-sans", codeID: "system-mono"), files: jetBrains, baseURL: base), "",
                       "The defaults are what the base style already uses")
        XCTAssertEqual(FontCSS.css(settings: FontSettings(bodyID: "no-such-font"), files: jetBrains, baseURL: base), "")
    }

    func testBundledFontMakesFontFaceAndRules() {
        let css = FontCSS.css(settings: FontSettings(codeID: "jetbrains-mono-nf"), files: jetBrains, baseURL: base)
        XCTAssertTrue(css.contains("@font-face { font-family: \"MD JetBrains Mono NF\"; src: url(\"md://app/Fonts/JetBrainsMonoNerdFont-Regular.ttf\") format(\"truetype\"); font-weight: 400; font-style: normal;"), css)
        XCTAssertTrue(css.contains("font-weight: 700; font-style: italic;"))
        XCTAssertTrue(css.contains("html body code, html body pre, html body kbd, html body samp, html body tt, html body code[class*=\"language-\"], html body pre[class*=\"language-\"] { font-family: \"MD JetBrains Mono NF\", ui-monospace"), css)
        XCTAssertFalse(css.contains("html body {"), "The body font was not changed")
        XCTAssertEqual(css.components(separatedBy: "@font-face").count - 1, 4)
    }

    func testCartographAlsoLoadsJetBrainsForTheIcons() {
        let css = FontCSS.css(settings: FontSettings(bodyID: "cartograph-cf-nf", codeID: "cartograph-cf-nf"),
                              files: jetBrains + cartograph, baseURL: base)
        XCTAssertTrue(css.contains("font-family: \"MD Cartograph CF NF\""))
        XCTAssertTrue(css.contains("html body { font-family: \"MD Cartograph CF NF\", \"MD JetBrains Mono NF\""), css)
        XCTAssertTrue(css.contains("JetBrainsMonoNerdFont-Regular.ttf"), "The icon fallback font must be loadable")
        XCTAssertEqual(css.components(separatedBy: "CartographCFNerdFont-Thin.ttf").count - 1, 1, "Each file once")
    }

    func testFileNamesAreEncodedInURLs() {
        let css = FontCSS.css(settings: FontSettings(bodyID: "jetbrains-mono-nf"), files: ["JetBrainsMonoNerdFont-Regular.ttf"], baseURL: "macdown-file:///My Apps/Fonts/".replacingOccurrences(of: " ", with: "%20"))
        XCTAssertTrue(css.contains("macdown-file:///My%20Apps/Fonts/JetBrainsMonoNerdFont-Regular.ttf"), css)
    }

    func testTypedFontNamesCannotInjectCSS() {
        XCTAssertEqual(FontCSS.sanitize("Fira Code"), "Fira Code")
        XCTAssertEqual(FontCSS.sanitize("  Iosevka-Term  "), "Iosevka-Term")
        let evil = "x\"; } body { display: none } /*"
        XCTAssertEqual(FontCSS.sanitize(evil), "x  body  display none")
        let css = FontCSS.css(settings: FontSettings(customBody: evil), files: [], baseURL: base)
        XCTAssertFalse(css.contains("display: none"), css)
        XCTAssertFalse(css.contains("}") && css.components(separatedBy: "}").count > 2, "Only our own single rule: \(css)")
        XCTAssertEqual(css.components(separatedBy: "{").count, 2, "Exactly one rule")
        XCTAssertEqual(FontCSS.css(settings: FontSettings(customBody: "\"';{}"), files: [], baseURL: base), "", "Nothing usable left: no rule")
    }

    func testTypedFamilyWinsOverTheChoiceAndKeepsAFallback() {
        let css = FontCSS.css(settings: FontSettings(bodyID: "system-serif", customBody: "Iosevka"), files: [], baseURL: base)
        XCTAssertTrue(css.hasPrefix("html body { font-family: \"Iosevka\", -apple-system"), css)
        let code = FontCSS.css(settings: FontSettings(customCode: "Fira Code"), files: [], baseURL: base)
        XCTAssertTrue(code.contains("html body code, html body pre"), code)
        XCTAssertTrue(code.contains("{ font-family: \"Fira Code\", ui-monospace"), code)
    }

    func testConfigNamesAreMatchedLeniently() {
        let files = jetBrains + cartograph
        XCTAssertEqual(FontCSS.settings(bodyName: nil, codeName: "Cartograph CF Nerd Font", files: files).codeID, "cartograph-cf-nf")
        XCTAssertEqual(FontCSS.settings(bodyName: nil, codeName: "jetbrains mono nerd font", files: files).codeID, "jetbrains-mono-nf")
        XCTAssertEqual(FontCSS.settings(bodyName: nil, codeName: "JetBrains-Mono-NF", files: files).codeID, "jetbrains-mono-nf", "The short id works too")
        XCTAssertEqual(FontCSS.settings(bodyName: nil, codeName: "JetBrains Mono Light", files: files).customCode, "JetBrains Mono Light", "Not a known name: a typed family")
        XCTAssertEqual(FontCSS.settings(bodyName: "Georgia", codeName: nil, files: files).bodyID, "georgia")
        XCTAssertEqual(FontCSS.settings(bodyName: "Some Unknown Font", codeName: nil, files: files).customBody, "Some Unknown Font")
        XCTAssertEqual(FontCSS.settings(bodyName: "", codeName: "", files: files), FontSettings())
    }

    func testSettingsAreCodableForStorage() throws {
        let s = FontSettings(bodyID: "georgia", codeID: "menlo", customBody: "", customCode: "Fira Code")
        XCTAssertEqual(try JSONDecoder().decode(FontSettings.self, from: JSONEncoder().encode(s)), s)
    }
}
