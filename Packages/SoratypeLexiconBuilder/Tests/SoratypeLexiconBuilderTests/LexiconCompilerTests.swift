import Testing
import SoratypeEngine
@testable import SoratypeLexiconBuilder

struct LexiconCompilerTests {
    @Test func roundTripReadsPackedWords() throws {
        let data = LexiconCompiler.compile(wordsInFrequencyOrder: ["the", "hey", "don't", "walking"])
        let lexicon = try MappedLexicon(data: data)
        #expect(lexicon.wordCount == 4)
        #expect(lexicon.contains("the"))
        #expect(lexicon.contains("hey"))
        #expect(lexicon.contains("don't"))
        #expect(lexicon.contains("walking"))
        #expect(!lexicon.contains("teh"))
        #expect(lexicon.rank(of: "the") == 1)
        let first = try #require(LetterByte.byte("t"))
        let last = try #require(LetterByte.byte("e"))
        #expect(lexicon.endpoints(first: first, last: last).contains("the"))
    }
}
