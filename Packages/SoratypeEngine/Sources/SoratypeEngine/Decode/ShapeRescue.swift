enum ShapeRescue {
    static func nominate(
        observations: [Observation],
        lexicon: any Lexicon,
        centers: KeyCenters,
        costs: DecodeCosts
    ) -> [SearchCandidate] {
        let strokeIDs = Set(observations.map(\.stroke).filter { $0 != 0 })
        guard !strokeIDs.isEmpty else { return [] }
        if observations.allSatisfy({ $0.stroke != 0 }), strokeIDs.count == 1 {
            return nominateChain(observations, lexicon: lexicon, centers: centers, costs: costs)
        }
        var found: [SearchCandidate] = []
        for stroke in strokeIDs {
            let chain = observations.filter { $0.stroke == stroke }
            let others = observations.filter { $0.stroke != stroke }
            for candidate in nominateChain(chain, lexicon: lexicon, centers: centers, costs: costs) {
                let word = LetterByte.spelling(candidate.bytes)
                guard othersSpellRemainder(word, chain: chain, others: others) else { continue }
                found.append(candidate)
            }
        }
        return found
    }

    private static func nominateChain(
        _ observations: [Observation],
        lexicon: any Lexicon,
        centers: KeyCenters,
        costs: DecodeCosts
    ) -> [SearchCandidate] {
        guard observations.allSatisfy({ $0.stroke != 0 }), !observations.isEmpty else { return [] }
        let aimed = AimedSpelling.observations(observations)
        guard let first = aimed.first?.letter, let last = aimed.last?.letter else { return [] }
        var found: [SearchCandidate] = []
        for word in lexicon.endpoints(first: first, last: last) {
            guard PathCheck.explains(word, observations: observations, centers: centers) else { continue }
            guard let rank = lexicon.rank(of: word) else { continue }
            let place = Double(Int(rank) - 1) / Double(max(lexicon.wordCount - 1, 1))
            found.append(SearchCandidate(
                bytes: Array(word.utf8),
                shifts: 0,
                score: -0.8 - costs.frequencyWeight * place
            ))
        }
        return found
    }

    private static func othersSpellRemainder(_ word: String, chain: [Observation], others: [Observation]) -> Bool {
        var letters = Array(word.utf8)
        for letter in AimedSpelling.observations(chain).map(\.letter) {
            guard let index = letters.firstIndex(of: letter) else { return false }
            letters.remove(at: index)
        }
        return AimedSpelling.observations(others).map(\.letter) == letters
    }
}
