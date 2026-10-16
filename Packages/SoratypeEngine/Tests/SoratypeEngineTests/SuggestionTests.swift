import Testing
@testable import SoratypeEngine

struct SuggestionTests {
    @Test func dontGainsAnApostropheWhenTheBareFormIsAWord() {
        var script = contractionScript("dont", "don't")
        script.tap("dont")
        script.space()
        #expect(script.text == "don't ")
        #expect(script.engine.strip.chips.count == 3)
        #expect(script.engine.strip.chips.contains { $0.text.lowercased() == "dont" })
    }

    @Test func imGainsItsApostropheAndCapital() {
        var script = contractionScript("im", "I'm")
        script.tap("im")
        script.space()
        #expect(script.text == "I'm ")
        #expect(script.engine.strip.chips.count == 3)
        #expect(script.engine.strip.chips.contains { $0.text.lowercased() == "im" })
    }

    @Test func cantGainsAnApostropheWhenTheBareFormIsAWord() {
        var script = contractionScript("cant", "can't")
        script.tap("cant")
        script.space()
        #expect(script.text == "can't ")
        #expect(script.engine.strip.chips.count == 3)
        #expect(script.engine.strip.chips.contains { $0.text.lowercased() == "cant" })
    }

    @Test func shouldntGainsAnApostrophe() {
        var script = contractionScript("shouldnt", "shouldn't")
        script.tap("shouldnt")
        script.space()
        #expect(script.text == "shouldn't ")
        #expect(script.engine.strip.chips.count == 3)
    }

    @Test func aNoisyAimedSpellingStaysOffTheStrip() {
        var script = Script(words: Fixture.words + ["of"], followers: ["pill": ["of", "the"]])
        script.swipe("pil")
        script.elapseGrace()
        #expect(script.text == "pill ")
        #expect(script.engine.strip.chips.contains { $0.text.lowercased() == "pil" } == false)
        #expect(script.engine.strip.chips.count == 3)
    }

    @Test func deletingASwipeLetsTheBareFormLeadTheRedraw() {
        var script = contractionScript("dont", "don't")
        script.swipe("dont")
        script.elapseGrace()
        #expect(script.text == "don't ")
        script.backspace()
        script.swipe("dont")
        script.elapseGrace()
        #expect(script.text == "dont ")
        #expect(script.engine.learning.refusals.contains { $0.word == "don't" })
    }

    @Test func aDifferentShapeDoesNotPunishTheDeletedWord() {
        var script = contractionScript("dont", "don't")
        script.swipe("dont")
        script.elapseGrace()
        script.backspace()
        script.tap("cat")
        script.space()
        #expect(script.text == "cat ")
        #expect(script.engine.learning.refusals.isEmpty)
    }

    private func contractionScript(_ bare: String, _ contraction: String) -> Script {
        Script(
            words: [bare, contraction, "know", "cat"],
            followers: [contraction: ["know"], bare: ["know"]]
        )
    }
}
