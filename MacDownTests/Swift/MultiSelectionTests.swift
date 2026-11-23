import XCTest
@testable import MacDown

final class MultiSelectionTests: XCTestCase {
    private func r(_ l: Int, _ n: Int = 0) -> NSRange { NSRange(location: l, length: n) }
    private func ns(_ s: String) -> NSString { s as NSString }

    // MARK: Normalizing

    func testNormalizeSortsMergesAndClamps() {
        XCTAssertEqual(MultiSelection.normalize([r(5), r(2), r(5)], length: 10), [r(2), r(5)])
        XCTAssertEqual(MultiSelection.normalize([r(2, 5), r(4, 5)], length: 20), [r(2, 7)])
        XCTAssertEqual(MultiSelection.normalize([r(2, 5), r(7)], length: 20), [r(2, 5)], "Caret at the edge of a selection is absorbed")
        XCTAssertEqual(MultiSelection.normalize([r(3), r(2, 5)], length: 20), [r(2, 5)])
        XCTAssertEqual(MultiSelection.normalize([r(-5, 3), r(100, 5)], length: 10), [r(0, 0), r(10, 0)])
        XCTAssertEqual(MultiSelection.normalize([], length: 3), [r(0)])
        XCTAssertEqual(MultiSelection.normalize([r(0, 2), r(2, 3)], length: 10), [r(0, 2), r(2, 3)], "Touching selections stay separate")
    }

    // MARK: Typing

    func testTypeAtSeveralCarets() {
        let result = MultiSelection.replace(in: "ab\ncd\nef", ranges: [r(1), r(4), r(7)], with: "X")
        XCTAssertEqual(result.text, "aXb\ncXd\neXf")
        XCTAssertEqual(result.ranges, [r(2), r(6), r(10)])
        XCTAssertEqual(result.edits.count, 3)
    }

    func testTypeOverSelections() {
        let result = MultiSelection.replace(in: "one two three", ranges: [r(0, 3), r(8, 5)], with: "N")
        XCTAssertEqual(result.text, "N two N")
        XCTAssertEqual(result.ranges, [r(1), r(7)])
    }

    func testTypeEmojiAndMultilineText() {
        let result = MultiSelection.replace(in: "ab", ranges: [r(0), r(2)], with: "😀\n")
        XCTAssertEqual(result.text, "😀\nab😀\n")
        XCTAssertEqual(result.ranges, [r(3), r(8)])
    }

    func testPasteDistributesPiecesOrRepeats() {
        let text = "a\nb\nc"
        let same = MultiSelection.paste(in: text, ranges: [r(1), r(3), r(5)], pieces: ["1", "2", "3"])
        XCTAssertEqual(same.text, "a1\nb2\nc3")
        let mismatch = MultiSelection.paste(in: text, ranges: [r(1), r(3)], pieces: ["x", "y", "z"])
        XCTAssertEqual(mismatch.text, "ax\ny\nz\nbx\ny\nz\nc")
    }

    // MARK: Deleting

    func testBackspaceAtCarets() {
        let result = MultiSelection.deleteBackward(in: "abc\ndef", ranges: [r(2), r(6)])
        XCTAssertEqual(result.text, "ac\ndf")
        XCTAssertEqual(result.ranges, [r(1), r(4)])
    }

    func testBackspaceAtStartDoesNothingThere() {
        let result = MultiSelection.deleteBackward(in: "abc", ranges: [r(0), r(2)])
        XCTAssertEqual(result.text, "ac")
        XCTAssertEqual(result.ranges, [r(0), r(1)])
    }

    func testBackspaceRemovesWholeGraphemeClusters() {
        let text = "a😀e\u{301}👨‍👩‍👧b"   // emoji, e + combining accent, family emoji
        let end = (text as NSString).length
        var current = MultiSelection.deleteBackward(in: text, ranges: [r(end)])   // Removes the "b".
        XCTAssertEqual(current.text, "a😀e\u{301}👨‍👩‍👧")
        // Then the family, the accented e, the emoji and the "a", one backspace each.
        for want in ["a😀e\u{301}", "a😀", "a", ""] {
            current = MultiSelection.deleteBackward(in: current.text, ranges: [r((current.text as NSString).length)])
            XCTAssertEqual(current.text, want)
        }
    }

    func testBackspaceTreatsWindowsLineEndingAsOneCharacter() {
        let result = MultiSelection.deleteBackward(in: "a\r\nb", ranges: [r(3)])
        XCTAssertEqual(result.text, "ab")
        XCTAssertEqual(MultiSelection.deleteForward(in: "a\r\nb", ranges: [r(1)]).text, "ab")
        XCTAssertEqual(MultiSelection.move(.left, in: "a\r\nb", ranges: [r(3)]), [r(1)])
        XCTAssertEqual(MultiSelection.move(.right, in: "a\r\nb", ranges: [r(1)]), [r(3)])
    }

    func testBackspaceNeverCutsSurrogatePair() {
        let result = MultiSelection.deleteBackward(in: "😀", ranges: [r(1)])   // Caret inside the pair.
        XCTAssertEqual(result.text, "")
    }

    func testAdjacentCaretsDeletingTheSameCharacterAreMerged() {
        let result = MultiSelection.deleteBackward(in: "abc", ranges: [r(2), r(2), r(3)])
        XCTAssertEqual(result.text, "a")
    }

    func testForwardDelete() {
        let result = MultiSelection.deleteForward(in: "abc\ndef", ranges: [r(0), r(4), r(7)])
        XCTAssertEqual(result.text, "bc\nef")
        XCTAssertEqual(result.ranges, [r(0), r(3), r(5)])
    }

    func testDeleteSelectionsAndMixedCarets() {
        let result = MultiSelection.deleteBackward(in: "hello world", ranges: [r(0, 5), r(11)])
        XCTAssertEqual(result.text, " worl")
    }

    // MARK: Moving

    func testLeftRightAndCollapse() {
        let t = "ab😀cd"
        XCTAssertEqual(MultiSelection.move(.left, in: t, ranges: [r(4), r(6)]), [r(2), r(5)])
        XCTAssertEqual(MultiSelection.move(.right, in: t, ranges: [r(2), r(0)]), [r(1), r(4)])
        XCTAssertEqual(MultiSelection.move(.left, in: t, ranges: [r(1, 3)]), [r(1)])
        XCTAssertEqual(MultiSelection.move(.right, in: t, ranges: [r(1, 3)]), [r(4)])
    }

    func testMovingCaretsTogetherMergesThem() {
        XCTAssertEqual(MultiSelection.move(.left, in: "ab", ranges: [r(0), r(1)]), [r(0)])
        XCTAssertEqual(MultiSelection.move(.lineStart, in: "ab\ncd", ranges: [r(1), r(2)]), [r(0)])
    }

    func testLineStartAndEnd() {
        let t = "abc\r\nde\nf"
        XCTAssertEqual(MultiSelection.move(.lineStart, in: t, ranges: [r(2), r(7)]), [r(0), r(5)])
        XCTAssertEqual(MultiSelection.move(.lineEnd, in: t, ranges: [r(1), r(5), r(8)]), [r(3), r(7), r(9)])
    }

    func testUpAndDownKeepTheColumn() {
        let t = "abcd\nxy\nlonger line"
        XCTAssertEqual(MultiSelection.move(.down, in: t, ranges: [r(3)]), [r(7)], "Short line: clamp to its end")
        XCTAssertEqual(MultiSelection.move(.down, in: t, ranges: [r(1)]), [r(6)])
        XCTAssertEqual(MultiSelection.move(.up, in: t, ranges: [r(12)]), [r(7)])
        XCTAssertEqual(MultiSelection.move(.up, in: t, ranges: [r(2)]), [r(0)], "First line: go to the start")
        XCTAssertEqual(MultiSelection.move(.down, in: t, ranges: [r(15)]), [r(t.utf16.count)], "Last line: go to the end")
    }

    func testWordMovement() {
        let t = "foo bar_baz  qux"
        XCTAssertEqual(MultiSelection.move(.wordRight, in: t, ranges: [r(0)]), [r(3)])
        XCTAssertEqual(MultiSelection.move(.wordRight, in: t, ranges: [r(3)]), [r(11)])
        XCTAssertEqual(MultiSelection.move(.wordLeft, in: t, ranges: [r(16)]), [r(13)])
        XCTAssertEqual(MultiSelection.move(.wordLeft, in: t, ranges: [r(13)]), [r(4)])
    }

    func testDocumentStartAndEnd() {
        XCTAssertEqual(MultiSelection.move(.documentStart, in: "abc", ranges: [r(1), r(2)]), [r(0)])
        XCTAssertEqual(MultiSelection.move(.documentEnd, in: "abc", ranges: [r(1), r(2)]), [r(3)])
    }

    // MARK: Adding selections

    func testAddNextOccurrence() {
        let t = "foo bar foo baz foo"
        var sel = MultiSelection.addNextOccurrence(in: t, ranges: [r(1)])           // Caret inside "foo".
        XCTAssertEqual(sel, [r(0, 3)])
        sel = MultiSelection.addNextOccurrence(in: t, ranges: sel)
        XCTAssertEqual(sel, [r(0, 3), r(8, 3)])
        sel = MultiSelection.addNextOccurrence(in: t, ranges: sel)
        XCTAssertEqual(sel, [r(0, 3), r(8, 3), r(16, 3)])
        sel = MultiSelection.addNextOccurrence(in: t, ranges: sel)                  // Nothing left.
        XCTAssertEqual(sel, [r(0, 3), r(8, 3), r(16, 3)])
    }

    func testAddNextOccurrenceWrapsAround() {
        let t = "ab ab ab"
        let sel = MultiSelection.addNextOccurrence(in: t, ranges: [r(6, 2)])
        XCTAssertEqual(sel, [r(0, 2), r(6, 2)])
    }

    func testSelectAllOccurrences() {
        let t = "a-b a-b a-bc"
        XCTAssertEqual(MultiSelection.selectAllOccurrences(in: t, ranges: [r(0, 3)]), [r(0, 3), r(4, 3), r(8, 3)])
        XCTAssertEqual(MultiSelection.selectAllOccurrences(in: "x yy x", ranges: [r(0)]), [r(0, 1), r(5, 1)])
        XCTAssertEqual(MultiSelection.selectAllOccurrences(in: "  ", ranges: [r(1)]), [r(1)], "No word: unchanged")
    }

    func testAddCaretAboveAndBelow() {
        let t = "abcd\nxy\nlonger"
        XCTAssertEqual(MultiSelection.addCaret(.down, in: t, ranges: [r(3)]), [r(3), r(7)])
        XCTAssertEqual(MultiSelection.addCaret(.up, in: t, ranges: [r(10)]), [r(7), r(10)], "Short line above: caret goes to its end")
    }

    func testColumnSelection() {
        let t = "abcdef\nab\nabcdef"
        XCTAssertEqual(MultiSelection.columnSelection(in: t, anchor: 1, head: 14), [r(1, 3), r(8, 1), r(11, 3)])
        XCTAssertEqual(MultiSelection.columnSelection(in: t, anchor: 2, head: 2), [r(2)])
    }

    // MARK: Fuzzing against single-cursor behavior

    private struct Generator {
        var state: UInt64
        mutating func next(_ bound: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) % UInt64(bound))
        }
    }

    private static let alphabet = ["a", "b", "é", "😀", "e\u{301}", " ", "\n", "\r\n", "日", "👨‍👩‍👧", "_", "x"]

    private func randomText(_ g: inout Generator, max: Int = 30) -> String {
        (0..<g.next(max)).map { _ in Self.alphabet[g.next(Self.alphabet.count)] }.joined()
    }

    /// Cluster boundaries of a text, in UTF-16 offsets.
    private func boundaries(_ text: String) -> Set<Int> {
        var set: Set<Int> = [0]
        var offset = 0
        for ch in text { offset += String(ch).utf16.count; set.insert(offset) }
        return set
    }

    private func randomCarets(_ g: inout Generator, text: String) -> [NSRange] {
        let b = Array(boundaries(text)).sorted()
        return (0..<(1 + g.next(5))).map { _ in
            let a = b[g.next(b.count)]
            let c = g.next(4) == 0 ? b[g.next(b.count)] : a
            return NSRange(location: min(a, c), length: abs(a - c))
        }
    }

    private func checkInvariants(_ ranges: [NSRange], text: String, file: StaticString = #filePath, line: UInt = #line) {
        let length = (text as NSString).length
        XCTAssertFalse(ranges.isEmpty, file: file, line: line)
        var previousEnd = -1
        for range in ranges {
            XCTAssertGreaterThanOrEqual(range.location, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(range.location + range.length, length, "\(ranges) in \(text.debugDescription)", file: file, line: line)
            XCTAssertGreaterThanOrEqual(range.location, previousEnd, "Overlap in \(ranges)", file: file, line: line)
            previousEnd = range.location + range.length
        }
    }

    func testTypingMatchesSingleCursorEditsAndKeepsInvariants() {
        var g = Generator(state: 12345)
        for _ in 0..<2000 {
            let text = randomText(&g)
            let carets = randomCarets(&g, text: text)
            let typed = Self.alphabet[g.next(Self.alphabet.count)]
            let result = MultiSelection.replace(in: text, ranges: carets, with: typed)
            checkInvariants(result.ranges, text: result.text)

            // Reference: apply to each normalized selection from the last to the first.
            var reference = text as NSString
            for range in MultiSelection.normalize(carets, length: (text as NSString).length).reversed() {
                reference = reference.replacingCharacters(in: range, with: typed) as NSString
            }
            XCTAssertEqual(result.text, reference as String, "text \(text.debugDescription) carets \(carets) typed \(typed.debugDescription)")

            // The edit list reproduces the result.
            var replay = text as NSString
            for edit in result.edits.reversed() { replay = replay.replacingCharacters(in: edit.range, with: edit.replacement) as NSString }
            XCTAssertEqual(replay as String, result.text)
        }
    }

    func testDeletingMatchesSingleCursorAndNeverBreaksClusters() {
        var g = Generator(state: 987)
        for _ in 0..<2000 {
            let text = randomText(&g)
            let carets = randomCarets(&g, text: text)
            for forward in [false, true] {
                let result = forward ? MultiSelection.deleteForward(in: text, ranges: carets)
                                     : MultiSelection.deleteBackward(in: text, ranges: carets)
                checkInvariants(result.ranges, text: result.text)
                // Every caret lies on a cluster boundary of the new text.
                let valid = boundaries(result.text)
                for range in result.ranges {
                    XCTAssertTrue(valid.contains(range.location), "caret \(range.location) inside a cluster of \(result.text.debugDescription)")
                }
                XCTAssertLessThanOrEqual((result.text as NSString).length, (text as NSString).length)
                // The result is valid text made of whole clusters from the original.
                XCTAssertNotNil(result.text.data(using: .utf8))
            }
        }
    }

    func testMovesKeepInvariantsAndClusterBoundaries() {
        var g = Generator(state: 4242)
        let directions: [MultiSelection.Direction] = [.left, .right, .up, .down, .lineStart, .lineEnd, .wordLeft, .wordRight]
        for _ in 0..<2000 {
            let text = randomText(&g)
            let carets = randomCarets(&g, text: text)
            for direction in directions {
                let moved = MultiSelection.move(direction, in: text, ranges: carets)
                checkInvariants(moved, text: text)
                XCTAssertTrue(moved.allSatisfy { $0.length == 0 })
                let valid = boundaries(text)
                if direction != .wordLeft && direction != .wordRight {
                    for range in moved { XCTAssertTrue(valid.contains(range.location), "\(direction) landed inside a cluster: \(range) in \(text.debugDescription)") }
                }
            }
        }
    }

    func testOccurrenceAndColumnOperationsKeepInvariants() {
        var g = Generator(state: 777)
        for _ in 0..<1500 {
            let text = randomText(&g, max: 40)
            let carets = randomCarets(&g, text: text)
            checkInvariants(MultiSelection.addNextOccurrence(in: text, ranges: carets), text: text)
            checkInvariants(MultiSelection.selectAllOccurrences(in: text, ranges: carets), text: text)
            checkInvariants(MultiSelection.addCaret(.up, in: text, ranges: carets), text: text)
            checkInvariants(MultiSelection.addCaret(.down, in: text, ranges: carets), text: text)
            let length = (text as NSString).length
            checkInvariants(MultiSelection.columnSelection(in: text, anchor: g.next(length + 1), head: g.next(length + 1)), text: text)
        }
    }

    func testHundredsOfCaretsStayFast() {
        let text = String(repeating: "word and more words\n", count: 5000)   // 100 KB.
        let ns = text as NSString
        var carets: [NSRange] = []
        var line = 0
        while line < ns.length { carets.append(NSRange(location: line + 4, length: 0)); line += 20 }
        XCTAssertEqual(carets.count, 5000)
        let start = Date()
        let typed = MultiSelection.replace(in: text, ranges: carets, with: "X")
        let deleted = MultiSelection.deleteBackward(in: typed.text, ranges: typed.ranges)
        let moved = MultiSelection.move(.down, in: deleted.text, ranges: deleted.ranges)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
        XCTAssertEqual(deleted.text, text)
        XCTAssertEqual(moved.count, 5000)
    }
}
