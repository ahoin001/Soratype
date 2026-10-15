import Testing
@testable import LeanTypeEngine

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
}
