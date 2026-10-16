import Testing
@testable import SoratypeEngine

struct WorkedExampleTests {
    @Test func heyJoinsAcrossALongPause() {
        var script = Script()
        script.tap("h", finger: 1)
        script.wait(5_000)
        #expect(script.engine.phase == .tapOpen)
        script.swipe("ey", finger: 2)
        #expect(script.engine.phase == .tapOpen)
        script.space()
        #expect(script.text == "hey ")
    }

    @Test func howdyStaysOneWordWhileAFingerIsDown() {
        var script = Script()
        script.down("h", finger: 1)
        script.wait(16)
        script.move("o", finger: 1)
        script.down("w", finger: 2)
        script.wait(16)
        script.move("d", finger: 2)
        script.up(1)
        script.wait(16)
        script.move("y", finger: 2)
        script.up(2)
        script.elapseGrace()
        #expect(script.text == "howdy ")
    }

    @Test func howdyGapJoinsWhenTheFragmentIsWeak() {
        var script = Script()
        script.swipe("ho", finger: 1)
        script.wait(40)
        script.swipe("wdy", finger: 2)
        script.elapseGrace()
        #expect(script.text == "howdy ")
    }

    @Test func graceOffSplitsAHandOff() {
        var script = Script(settings: EngineSettings(handoffGraceEnabled: false))
        script.swipe("ho", finger: 1)
        script.wait(40)
        script.swipe("wdy", finger: 2)
        script.elapseGrace()
        #expect(script.text != "howdy ")
        #expect(script.text.contains(" "))
    }

    @Test func thePlusNStaysSplitInsideGrace() {
        var script = Script()
        script.swipe("the", finger: 1)
        script.wait(20)
        script.tap("n", finger: 2)
        #expect(script.text == "the n")
        #expect(!script.text.contains("then"))
    }

    @Test func stayCommitsWhenTheLastFingerLifts() {
        var script = Script()
        script.down("s", finger: 2)
        script.wait(220)
        script.tap("t", finger: 1)
        script.move("a", finger: 2)
        script.tap("y", finger: 1)
        script.up(2)
        script.elapseGrace()
        #expect(script.text == "stay ")
    }

    @Test func plantedLetterShowsBeforeTheFingerMoves() {
        var script = Script()
        script.down("s", finger: 2)
        script.wait(40)
        script.tap("ta", finger: 1)
        #expect(script.text.contains("s"))
        #expect(script.text.hasSuffix(" ") == false)
        script.move("y", finger: 2)
        let planted = script.engine.observations.filter { $0.letter == LetterByte.byte("s") }
        #expect(planted.count == 1)
        #expect(planted.first?.kind == .pin)
        script.up(2)
        script.elapseGrace()
        #expect(script.text == "stay ")
    }

    @Test func plantedLetterStaysAfterALongHold() {
        var script = Script()
        script.down("s", finger: 2)
        script.wait(600)
        script.tap("ta", finger: 1)
        script.move("y", finger: 2)
        let planted = script.engine.observations.filter { $0.letter == LetterByte.byte("s") }
        #expect(planted.count == 1)
        #expect(planted.first?.kind == .pin)
        script.up(2)
        script.elapseGrace()
        #expect(script.text == "stay ")
    }

    @Test func plantedLetterWithoutTravelStaysOpenUntilSpace() {
        var script = Script()
        script.down("s", finger: 2)
        script.wait(40)
        script.tap("tay", finger: 1)
        script.up(2)
        #expect(script.engine.phase == .tapOpen)
        #expect(script.text.contains("s"))
        #expect(script.text.hasSuffix(" ") == false)
        script.space()
        #expect(script.text == "stay ")
    }

    @Test func quitMixesATapASwipeAndATap() {
        var script = Script()
        script.tap("q", finger: 2)
        script.swipe("ui", finger: 1)
        script.tap("t", finger: 2)
        script.space()
        #expect(script.text == "quit ")
    }

    @Test func privateSurvivesAPauseBetweenSwipes() {
        var script = Script()
        script.tap("p", finger: 1)
        script.tap("r", finger: 2)
        script.tap("i", finger: 1)
        script.wait(800)
        script.swipe("va", finger: 2)
        script.wait(800)
        script.swipe("te", finger: 2)
        script.space()
        #expect(script.text == "private ")
    }

    @Test func friendFromAlternatingTaps() {
        var script = Script()
        script.tap("f", finger: 2)
        script.tap("r", finger: 1)
        script.tap("i", finger: 2)
        script.tap("e", finger: 1)
        script.tap("n", finger: 2)
        script.tap("d", finger: 1)
        script.space()
        #expect(script.text == "friend ")
    }

    @Test func waitJoinsTheTapWhileTheSwipeIsDown() {
        var script = Script()
        script.down("w", finger: 2)
        script.wait(16)
        script.move("a", finger: 2)
        script.tap("i", finger: 1)
        script.move("t", finger: 2)
        script.up(2)
        script.elapseGrace()
        #expect(script.text == "wait ")
    }

    @Test func waitSplitsAfterEveryFingerLifts() {
        var script = Script()
        script.swipe("wa", finger: 2)
        script.elapseGrace()
        script.tap("it", finger: 1)
        script.space()
        #expect(script.text != "wait ")
        #expect(script.text.contains(" "))
    }

    @Test func pillDoublesTheFinalLetter() {
        var script = Script()
        script.swipe("pil", finger: 1)
        script.elapseGrace()
        #expect(script.text == "pill ")
    }

    @Test func pileUsesTheTapDuringTheStroke() {
        var script = Script()
        script.down("p", finger: 1)
        script.wait(16)
        script.move("i", finger: 1)
        script.wait(16)
        script.move("l", finger: 1)
        script.tap("e", finger: 2)
        script.up(1)
        script.elapseGrace()
        #expect(script.text == "pile ")
    }

    @Test func eAfterTheLiftIsTheNextWord() {
        var script = Script()
        script.swipe("pil", finger: 1)
        script.elapseGrace()
        script.tap("e", finger: 2)
        #expect(script.text == "pill e")
    }

    @Test func intenseKeepsOneWordAcrossHandOffs() {
        var script = Script()
        script.down("i", finger: 1)
        script.wait(16)
        script.move("n", finger: 1)
        script.down("t", finger: 2)
        script.wait(16)
        script.move("e", finger: 2)
        script.up(1)
        script.tap("n", finger: 1)
        script.move("s", finger: 2)
        script.wait(16)
        script.move("e", finger: 2)
        script.up(2)
        script.elapseGrace()
        #expect(script.text == "intense ")
    }

    @Test func estrangedKeepsTheTapInsideTheStroke() {
        var script = Script()
        script.down("e", finger: 2)
        for character: Character in ["s", "t", "r", "a"] {
            script.wait(12)
            script.move(character, finger: 2)
        }
        script.tap("n", finger: 1)
        for character: Character in ["g", "e", "d"] {
            script.wait(12)
            script.move(character, finger: 2)
        }
        script.up(2)
        script.elapseGrace()
        #expect(script.text == "estranged ")
    }

    @Test func walkingJoinsAKnownSuffix() {
        var script = Script()
        script.swipe("walk", finger: 1)
        script.elapseGrace()
        script.tap("ing", finger: 2)
        script.space()
        #expect(script.text == "walking ")
    }

    @Test func tehCorrectsAtSpace() {
        var script = Script()
        script.tap("teh")
        script.space()
        #expect(script.text == "the ")
    }

    @Test func dontGainsAnApostrophe() {
        var script = Script()
        script.tap("dont")
        script.space()
        #expect(script.text == "don't ")
    }

    @Test func arrivalStampKeepsCatInOrder() {
        var script = Script()
        script.down("c", finger: 2)
        script.wait(16)
        script.move("a", finger: 2)
        script.wait(220)
        script.tap("t", finger: 1)
        script.up(2)
        script.elapseGrace()
        #expect(script.text == "cat ")
    }

    @Test func privateSurvivesNeighborKeysBetweenLetters() {
        var script = Script()
        script.tap("p", finger: 1)
        script.tap("r", finger: 2)
        script.tap("i", finger: 1)
        script.wait(800)
        script.swipe(along: "va", finger: 2)
        script.wait(800)
        script.swipe(along: "te", finger: 2)
        script.space()
        #expect(script.text == "private ")
    }

    @Test func quitSurvivesNeighborKeysOnTheSwipe() {
        var script = Script()
        script.tap("q", finger: 2)
        script.swipe(along: "ui", finger: 1)
        script.tap("t", finger: 2)
        script.space()
        #expect(script.text == "quit ")
    }

    @Test func waitJoinsThroughNeighborKeys() {
        var script = Script()
        script.down("w", finger: 2)
        script.trace(from: "w", to: "a", finger: 2)
        script.move("a", finger: 2)
        script.tap("i", finger: 1)
        script.trace(from: "a", to: "t", finger: 2)
        script.move("t", finger: 2)
        script.up(2)
        script.elapseGrace()
        #expect(script.text == "wait ")
    }

    @Test func tapThenStrokesThenALetterStayOneWord() {
        var script = Script()
        script.tap("m", finger: 1)
        script.swipe(along: "ea", finger: 2)
        script.swipe(along: "nin", finger: 1)
        script.tap("g", finger: 2)
        script.space()
        #expect(script.text == "meaning ")
    }
}
