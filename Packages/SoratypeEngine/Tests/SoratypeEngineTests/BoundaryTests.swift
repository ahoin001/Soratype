import Testing
@testable import SoratypeEngine

struct BoundaryTests {
    @Test func queuedSpaceWaitsForTheLift() {
        var script = Script()
        script.tap("h")
        script.down("e", finger: 2)
        script.space()
        #expect(script.text == "h")
        script.up(2)
        #expect(script.text == "he ")
    }

    @Test func queuedBackspaceDoesNotSplitTheWord() {
        var script = Script()
        script.tap("he")
        script.down("y", finger: 2)
        script.backspace()
        #expect(script.text == "hey" || script.text == "he")
        script.up(2)
        #expect(script.text == "he")
    }

    @Test func swipeBackspaceRemovesTheWordAndKeepsAimedLetters() {
        var script = Script()
        script.swipe("pil")
        script.elapseGrace()
        #expect(script.text == "pill ")
        script.backspace()
        #expect(script.text.isEmpty)
        #expect(script.engine.strip.chips.contains { $0.text.lowercased() == "pil" })
    }

    @Test func reopenAimedLettersIsASetting() {
        var script = Script(settings: EngineSettings(backspaceMode: .reopenAimedLetters))
        script.swipe("pil")
        script.elapseGrace()
        script.backspace()
        #expect(script.text == "pil")
        #expect(script.engine.phase == .tapOpen)
    }

    @Test func autocorrectBackspaceRestoresTheTypedLetters() {
        var script = Script()
        script.tap("teh")
        script.space()
        script.backspace()
        #expect(script.text == "teh")
        #expect(!script.text.hasSuffix(" "))
    }

    @Test func tapBackspaceReopensTheWord() {
        var script = Script()
        script.tap("cat")
        script.space()
        script.backspace()
        #expect(script.text == "cat")
        #expect(script.engine.phase == .tapOpen)
    }

    @Test func suffixBackspaceReopensTheSuffix() {
        var script = Script()
        script.swipe("walk")
        script.elapseGrace()
        script.tap("ing")
        script.space()
        #expect(script.text == "walking ")
        script.backspace()
        #expect(script.text == "walking")
        #expect(script.engine.field.composing == "ing")
    }

    @Test func doubleSpacePeriodRestoresTwoSpaces() {
        var script = Script()
        script.tap("hi")
        script.space()
        script.space()
        #expect(script.text == "hi. ")
        script.backspace()
        #expect(script.text == "hi  ")
    }

    @Test func dismissalSettlesOnce() {
        var script = Script()
        script.tap("h")
        script.dismiss()
        #expect(script.text == "h")
        let settles = script.engine.settleCount
        script.dismiss()
        #expect(script.engine.settleCount == settles)
        #expect(script.engine.phase == .idle)
    }

    @Test func settleIsIdempotent() {
        var script = Script()
        script.tap("h")
        script.space()
        #expect(script.engine.settleCount == 1)
        #expect(script.text == "h ")
        script.dismiss()
        #expect(script.engine.settleCount == 1)
        #expect(script.text == "h ")
    }

    @Test func hostChangeDropsTheSession() {
        var script = Script()
        script.tap("h")
        let settles = script.engine.settleCount
        script.engine.handle(.host(.textChanged("xyz", caret: 3)))
        #expect(script.text == "xyz")
        #expect(script.engine.phase == .idle)
        #expect(script.engine.settleCount == settles)
    }

    @Test func thirdFingerIsOnlyATap() {
        var script = Script()
        script.down("a", finger: 1)
        script.down("b", finger: 2)
        script.down("z", finger: 3)
        script.move("m", finger: 3)
        script.up(3)
        script.up(1)
        script.up(2)
        let zed = script.engine.observations.filter { $0.letter == LetterByte.byte("z") }
        #expect(zed.count == 1)
        #expect(zed.first?.kind == .tap)
        #expect(zed.first?.stroke == 0)
    }

    @Test func cancelBeforeTravelTypesNothing() {
        var script = Script()
        script.down("q", finger: 1)
        script.cancel(1)
        #expect(script.text.isEmpty)
        #expect(script.engine.phase == .idle)
    }

    @Test func cancelAfterTravelActsAsALift() {
        var script = Script()
        script.down("h", finger: 1)
        script.move("i", finger: 1)
        script.cancel(1)
        script.elapseGrace()
        #expect(script.text == "hi ")
    }

    @Test func spacesAndDismissalDoNotDoubleSettle() {
        var script = Script()
        script.tap("cat")
        script.space()
        script.tap("sat")
        script.space()
        let settles = script.engine.settleCount
        script.dismiss()
        script.engine.handle(.boundary(.caret(0)))
        #expect(script.engine.settleCount == settles)
        #expect(script.text == "cat sat ")
    }

    @Test func verbatimInsertsPlainLetters() {
        var script = Script()
        script.engine.handle(.host(.verbatim(true)))
        script.tap("hi")
        script.space()
        #expect(script.text == "hi ")
        #expect(script.engine.phase == .idle)
    }
}
