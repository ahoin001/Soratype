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

    @Test func curatedContractionFollowersAndOffensiveFlag() throws {
        let data = LexiconCompiler.compile(
            wordList: "the\nto\nlove\n",
            curated: "don't\n",
            offensive: "fuck\n",
            followers: "the\tto\n"
        )
        let lexicon = try MappedLexicon(data: data)
        #expect(lexicon.contains("don't"))
        #expect(lexicon.contains("fuck"))
        #expect(lexicon.isOffensive("fuck"))
        #expect(!lexicon.isOffensive("love"))
        let dont = try #require(lexicon.rank(of: "don't"))
        let the = try #require(lexicon.rank(of: "the"))
        #expect(dont < the)
        #expect(lexicon.followers(of: "the") == ["to"])

        let layout = KeyboardLayout.letters(fitting: Size(width: 390, height: 220))
        let love = AlignmentPathMatcher.match(DecodeRequest(
            observations: taps("love", layout: layout),
            centers: layout.centers,
            lexicon: lexicon
        ))
        #expect(love.readings.contains { $0.text.lowercased() == "fuck" } == false)
        let aimed = AlignmentPathMatcher.match(DecodeRequest(
            observations: taps("fuck", layout: layout),
            centers: layout.centers,
            lexicon: lexicon
        ))
        #expect(aimed.aimed == "fuck")
        #expect(aimed.readings.contains { $0.text.lowercased() == "fuck" })
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
