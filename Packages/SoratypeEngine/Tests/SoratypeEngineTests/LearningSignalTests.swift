import Testing
@testable import SoratypeEngine

struct LearningSignalTests {
    @Test func ignoredChipsFadeUntilTheWordIsAccepted() {
        var memory = LearningMemory()
        #expect(memory.shouldFade("hello") == false)
        memory.noteImpression("hello")
        memory.noteImpression("hello")
        #expect(memory.shouldFade("hello") == false)
        memory.noteImpression("hello")
        #expect(memory.shouldFade("hello"))
        memory.noteAccept("hello", previous: nil, now: 10)
        #expect(memory.shouldFade("hello") == false)
    }

    @Test func emailsUrlsAndDigitRunsAreNotLearned() {
        #expect(LearningMemory.skipsLearning("ada@example.com"))
        #expect(LearningMemory.skipsLearning("https://soratype.app"))
        #expect(LearningMemory.skipsLearning("481516"))
        #expect(LearningMemory.skipsLearning("hello") == false)
        var memory = LearningMemory()
        memory.noteAccept("ada@example.com", previous: nil, now: 1)
        #expect(memory.personal.isEmpty)
    }

    @Test func aLongPressRejectsTheWord() {
        var memory = LearningMemory()
        memory.noteReject("nope")
        #expect(memory.blocklist.contains("nope"))
        #expect(memory.shouldFade("nope"))
    }
}
