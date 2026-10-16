import Testing
@testable import SoratypeEngine

struct MixedInputTests {
    @Test func aSecondThumbLandsWhileTheFirstThumbIsStillMoving() {
        var script = Script(words: ["cant", "can't", "can", "cat"])
        script.down("c", finger: 1)
        script.move("a", finger: 1)
        script.down("n", finger: 2)
        let spelled = AimedSpelling.text(from: script.engine.observations)
        #expect(spelled.contains("n"))
        script.up(2)
        script.tap("t", finger: 2)
        script.up(1)
        script.elapseGrace()
        #expect(script.text == "can't ")
    }

    @Test func aSwipeThatMatchesNoWordStaysUnlearned() {
        var script = Script(words: ["hello"])
        script.swipe("qx")
        script.elapseGrace()
        #expect(script.text == "qx ")
        #expect(script.engine.learning.personal["qx"] == nil)
    }
}
