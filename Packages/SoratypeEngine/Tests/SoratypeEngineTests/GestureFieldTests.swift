import Testing
@testable import SoratypeEngine

struct GestureFieldTests {
    @Test func aRestedSpaceStillTypes() {
        var script = Script()
        script.tap("cat")
        _ = script.flickSpace(hold: 620)
        #expect(script.text == "cat ")
        #expect(script.engine.phase == .idle)
    }

    @Test func aSecondSpaceTypesWhenThePeriodSettingIsOff() {
        var script = Script(settings: EngineSettings(doubleSpacePeriod: false))
        script.tap("cat")
        script.space()
        script.space()
        #expect(script.text == "cat  ")
    }

    @Test func flickDownSettlesBeforeThePunctuationPage() {
        var script = Script()
        script.tap("cat")
        let effects = script.flickSpace(dy: 48)
        #expect(script.text == "cat ")
        #expect(script.engine.phase == .idle)
        #expect(effects.contains(.page(.punctuation)))
    }

    @Test func flickUpReturnsTheOpenWordPreview() {
        var script = Script()
        script.tap("cat")
        script.space()
        _ = script.flickSpace(dy: -48)
        #expect(script.engine.phase == .tapOpen)
        #expect(script.engine.field.composing.lowercased() == "cat")
        #expect(script.engine.strip.preview)
        #expect(script.engine.strip.chips.contains { $0.role == .leader && $0.text.lowercased() == "cat" })
    }

    @Test func aDeletedSwipeCanBeInsertedFromTheStrip() {
        var script = Script()
        script.swipe("pil")
        script.elapseGrace()
        #expect(script.text == "pill ")
        script.backspace()
        #expect(script.text.isEmpty)
        let index = script.engine.strip.chips.firstIndex { $0.role == .follower }
        #expect(index != nil)
        let word = script.engine.strip.chips[index!].text
        script.engine.handle(.acceptChip(index!))
        #expect(script.text == word + " ")
    }

    @Test func theFirstScrubStepClearsTheNextWord() {
        var script = Script(words: Fixture.words + ["of"], followers: ["the": ["of"]])
        script.tap("the")
        script.space()
        #expect(script.engine.strip.chips.contains { $0.role == .follower && $0.text.lowercased() == "of" })
        script.engine.handle(.boundary(.scrub(-1)))
        #expect(script.engine.strip.chips.contains { $0.role == .follower } == false)
        #expect(script.text == "the")
    }

    @Test func aHorizontalDragDeletesOneCharacter() {
        var script = Script()
        script.tap("cat")
        script.space()
        _ = script.flickSpace(dx: 80)
        script.backspace()
        #expect(script.engine.phase == .idle)
        #expect(script.text == "cat")
    }
}

extension Script {
    @discardableResult
    mutating func flickSpace(dx: Double = 0, dy: Double = 0, hold: Int = 30) -> [EngineEffect] {
        guard let key = layout.keys.first(where: { $0.kind == .space }) else {
            preconditionFailure("Missing space")
        }
        let origin = key.frame.center
        let end = Point(x: origin.x + dx, y: origin.y + dy)
        func touch(_ phase: TouchPhase, _ point: Point) -> EngineInput {
            .touch(TouchSample(
                time: EngineInstant(milliseconds: time),
                finger: FingerID(9),
                phase: phase,
                point: point,
                key: key
            ))
        }
        var effects = engine.handle(touch(.down, origin))
        time += 1
        if dx != 0 || dy != 0 {
            time += max(hold / 2, 1)
            effects += engine.handle(touch(.move, end))
            time += 1
        } else {
            time += hold
        }
        effects += engine.handle(touch(.up, end))
        time += 1
        return effects
    }
}
