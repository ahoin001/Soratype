import Testing
@testable import SoratypeEngine

struct DecoderTests {
    @Test func aimedLiveStaysAheadOfAMoreCommonLove() {
        let layout = KeyboardLayout.letters(fitting: Size(width: 390, height: 220))
        let lexicon = MemoryLexicon(wordsInFrequencyOrder: ["love", "live"])
        let observations = observations("live", layout: layout)
        let result = AlignmentPathMatcher.match(DecodeRequest(
            observations: observations,
            centers: layout.centers,
            learning: LearningSnapshot(habits: ["love": 0.45]),
            lexicon: lexicon
        ))
        #expect(result.top?.lowercased() == "live")
    }

    @Test func budgetFallbackKeepsAimedLetters() {
        let layout = KeyboardLayout.letters(fitting: Size(width: 390, height: 220))
        let lexicon = MemoryLexicon(wordsInFrequencyOrder: ["zzzzzz"])
        let result = AlignmentPathMatcher.match(DecodeRequest(
            observations: observations("qr", layout: layout),
            centers: layout.centers,
            lexicon: lexicon,
            budgetMilliseconds: 12
        ))
        #expect(result.aimed == "qr")
        #expect(result.top == "qr" || result.readings.isEmpty || result.top == result.aimed)
    }

    @Test func threeCenteredCrossingsStillReachTheWord() {
        let layout = KeyboardLayout.letters(fitting: Size(width: 390, height: 220))
        let lexicon = MemoryLexicon(wordsInFrequencyOrder: ["cat"])
        let observations = stroke([
            ("c", .anchor),
            ("r", .crossing),
            ("f", .crossing),
            ("g", .crossing),
            ("a", .anchor),
            ("t", .anchor),
        ], layout: layout)
        let result = AlignmentPathMatcher.match(DecodeRequest(
            observations: observations,
            centers: layout.centers,
            lexicon: lexicon
        ))
        #expect(result.aimed == "cat")
        #expect(result.top?.lowercased() == "cat")
    }

    private func observations(_ letters: String, layout: KeyboardLayout) -> [Observation] {
        letters.enumerated().compactMap { index, character in
            guard let key = layout.key(for: character), let byte = LetterByte.byte(character) else { return nil }
            return Observation(
                letter: byte,
                shifted: false,
                kind: .tap,
                thumb: .right,
                time: index * 40,
                x: key.frame.center.x,
                y: key.frame.center.y,
                keyX: key.frame.center.x,
                keyY: key.frame.center.y,
                keyWidth: key.frame.size.width,
                keyHeight: key.frame.size.height,
                centered: true,
                stroke: 0,
                otherThumbDown: false
            )
        }
    }

    private func stroke(
        _ marks: [(Character, ObservationKind)],
        layout: KeyboardLayout
    ) -> [Observation] {
        marks.enumerated().compactMap { index, mark in
            guard let key = layout.key(for: mark.0), let byte = LetterByte.byte(mark.0) else { return nil }
            return Observation(
                letter: byte,
                shifted: false,
                kind: mark.1,
                thumb: .right,
                time: index * 30,
                x: key.frame.center.x,
                y: key.frame.center.y,
                keyX: key.frame.center.x,
                keyY: key.frame.center.y,
                keyWidth: key.frame.size.width,
                keyHeight: key.frame.size.height,
                centered: true,
                stroke: 1,
                otherThumbDown: false
            )
        }
    }
}
