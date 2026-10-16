import Testing
@testable import SoratypeEngine

struct ForgivenessTests {
    @Test func tapThenStrokeSplitsIntoTwoWords() {
        var script = Script()
        script.tap("the")
        script.swipe("cat")
        #expect(script.text.contains("the"))
        #expect(script.text.contains("cat"))
        #expect(script.text.contains("thecat") == false)
    }

    @Test func leadingTapDoesNotHideTheStrokeWord() {
        let layout = KeyboardLayout.letters(fitting: Size(width: 390, height: 220))
        let lexicon = MemoryLexicon(wordsInFrequencyOrder: ["hello", "the"])
        var observations = taps("xhello", layout: layout)
        observations[0].stroke = 0
        observations[0].kind = .tap
        observations[0].lifted = true
        observations[0].liftTime = 20
        for index in observations.indices.dropFirst() {
            observations[index].stroke = 1
            observations[index].kind = .anchor
        }
        let result = AlignmentPathMatcher.match(DecodeRequest(
            observations: observations,
            centers: layout.centers,
            lexicon: lexicon
        ))
        #expect(result.top?.lowercased() == "hello")
        #expect(result.readings.contains { $0.text.lowercased() == "xhello" })
    }

    @Test func aTapStillHeldIsNotDroppedForTheStroke() {
        let layout = KeyboardLayout.letters(fitting: Size(width: 390, height: 220))
        let lexicon = MemoryLexicon(wordsInFrequencyOrder: ["hello", "the"])
        var observations = taps("xhello", layout: layout)
        observations[0].stroke = 0
        observations[0].kind = .tap
        observations[0].lifted = false
        for index in observations.indices.dropFirst() {
            observations[index].stroke = 1
            observations[index].kind = .anchor
        }
        let result = AlignmentPathMatcher.match(DecodeRequest(
            observations: observations,
            centers: layout.centers,
            lexicon: lexicon
        ))
        #expect(result.readings.contains { $0.text.lowercased() == "xhello" } == false)
    }

    @Test func anExtraTapDropsAStrokeNominationThatItDoesNotFinish() {
        let layout = KeyboardLayout.letters(fitting: Size(width: 390, height: 220))
        let lexicon = MemoryLexicon(wordsInFrequencyOrder: ["cat"])
        let stroke = taps("cat", layout: layout).map { observation -> Observation in
            var observation = observation
            observation.stroke = 1
            observation.kind = .anchor
            return observation
        }
        let alone = ShapeRescue.nominate(
            observations: stroke,
            lexicon: lexicon,
            centers: layout.centers,
            costs: .standard
        )
        #expect(alone.contains { LetterByte.spelling($0.bytes) == "cat" })
        var extra = taps("s", layout: layout)
        extra[0].time = 500
        let vetoed = ShapeRescue.nominate(
            observations: stroke + extra,
            lexicon: lexicon,
            centers: layout.centers,
            costs: .standard
        )
        #expect(vetoed.contains { LetterByte.spelling($0.bytes) == "cat" } == false)
    }

    @Test func flickDownOnSpaceOpensPunctuation() {
        var script = Script()
        let space = script.layout.keys.first { $0.kind == .space }!
        let origin = space.frame.center
        let dropped = Point(x: origin.x, y: origin.y + 40)
        func touch(_ phase: TouchPhase, _ point: Point) -> EngineInput {
            .touch(TouchSample(
                time: EngineInstant(milliseconds: script.time),
                finger: FingerID(3),
                phase: phase,
                point: point,
                key: space
            ))
        }
        var effects = script.engine.handle(touch(.down, origin))
        script.time += 20
        effects += script.engine.handle(touch(.move, dropped))
        script.time += 20
        effects += script.engine.handle(touch(.up, dropped))
        #expect(effects.contains(.page(.punctuation)))
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
