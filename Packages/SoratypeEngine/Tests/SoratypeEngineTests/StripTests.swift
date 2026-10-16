import Testing
@testable import SoratypeEngine

struct StripTests {
    @Test func followerTapInsertsTheNextWord() {
        var script = Script(words: Fixture.words + ["of"], followers: ["the": ["of"]])
        script.tap("the")
        script.space()
        let follower = script.engine.strip.chips.firstIndex { $0.role == .follower && $0.text.lowercased() == "of" }
        let context = script.engine.strip.chips.contains { $0.role == .context && $0.text.lowercased() == "the" }
        #expect(follower != nil)
        #expect(context)
        script.engine.handle(.acceptChip(follower!))
        #expect(script.text == "the of ")
        #expect((script.engine.learning.personal["of"] ?? 0) >= 1)
        #expect((script.engine.learning.pairs["the\tof"] ?? 0) >= 1)
    }

    @Test func correctionTapReplacesAndRecordsTheAccept() {
        var script = Script()
        script.swipe("pil")
        script.elapseGrace()
        #expect(script.text == "pill ")
        let aimed = script.engine.strip.chips.firstIndex { $0.role == .aimed && $0.text.lowercased() == "pil" }
        #expect(aimed != nil)
        script.engine.handle(.acceptChip(aimed!))
        #expect(script.text == "pil ")
        #expect((script.engine.learning.personal["pil"] ?? 0) >= 1)
    }

    @Test func threeIgnoresHideTheNextWord() {
        var script = Script(words: Fixture.words + ["of"], followers: ["the": ["of"]])
        for _ in 0..<3 {
            script.tap("the")
            script.space()
        }
        #expect(script.engine.strip.chips.contains { $0.role == .follower && $0.text.lowercased() == "of" })
        script.tap("the")
        script.space()
        #expect(script.engine.strip.chips.contains { $0.role == .follower } == false)
        #expect(script.engine.strip.chips.contains { $0.role == .context && $0.text.lowercased() == "the" })
    }

    @Test func longPressBlocksWithoutUntypingAndAnExactAimStillDecodes() {
        var script = Script(words: Fixture.words + ["of"], followers: ["the": ["of"]])
        script.tap("the")
        script.space()
        let follower = script.engine.strip.chips.firstIndex { $0.role == .follower }
        #expect(follower != nil)
        let before = script.text
        script.engine.handle(.rejectChip(follower!))
        #expect(script.text == before)
        #expect(script.engine.learning.blocklist.contains("of"))
        script.tap("the")
        script.space()
        #expect(script.engine.strip.chips.contains { $0.role == .follower && $0.text.lowercased() == "of" } == false)

        let layout = KeyboardLayout.letters(fitting: Size(width: 390, height: 220))
        let lexicon = MemoryLexicon(wordsInFrequencyOrder: ["of", "the"])
        let result = AlignmentPathMatcher.match(DecodeRequest(
            observations: taps("of", layout: layout),
            centers: layout.centers,
            learning: LearningSnapshot(blocked: ["of"]),
            lexicon: lexicon
        ))
        #expect(result.readings.contains { $0.text.lowercased() == "of" })
    }

    @Test func allowingAWordReturnsItWithoutErasingLearning() {
        var memory = LearningMemory()
        memory.noteReject("of")
        memory.noteAccept("of", previous: "the", now: 5)
        #expect(memory.blocklist.contains("of"))
        #expect(memory.personal["of"] == 1)
        memory.allow("of")
        #expect(memory.blocklist.contains("of") == false)
        #expect(memory.personal["of"] == 1)

        var blocked = LearningMemory()
        blocked.noteReject("of")
        var script = Script(words: Fixture.words + ["of"], followers: ["the": ["of"]], memory: blocked)
        script.tap("the")
        script.space()
        #expect(script.engine.strip.chips.contains { $0.text.lowercased() == "of" } == false)
        var learned = script.engine.learning
        learned.allow("of")
        script.engine.replaceLearning(learned)
        script.tap("the")
        script.space()
        #expect(script.engine.strip.chips.contains { $0.role == .follower && $0.text.lowercased() == "of" })
    }

    private func taps(_ letters: String, layout: KeyboardLayout) -> [Observation] {
        letters.enumerated().compactMap { index, character in
            guard let key = layout.key(for: character), let byte = LetterByte.byte(character) else { return nil }
            return Observation(
                letter: byte, shifted: false, kind: .tap, thumb: .right, time: index * 40,
                x: key.frame.center.x, y: key.frame.center.y,
                keyX: key.frame.center.x, keyY: key.frame.center.y,
                keyWidth: key.frame.size.width, keyHeight: key.frame.size.height,
                centered: true, stroke: 0, otherThumbDown: false
            )
        }
    }
}
