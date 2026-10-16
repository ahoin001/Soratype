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
            return nominateChain(observations, curve: observations, lexicon: lexicon, centers: centers, costs: costs)
        }
        var found: [SearchCandidate] = []
        for stroke in strokeIDs {
            let chain = observations.filter { $0.stroke == stroke }
            let others = observations.filter { $0.stroke != stroke }
            for candidate in nominateChain(chain, curve: observations, lexicon: lexicon, centers: centers, costs: costs) {
                let word = LetterByte.spelling(candidate.bytes)
                guard keepsStrongLetters(word, chain: chain, others: others) else { continue }
                found.append(candidate)
            }
        }
        return found
    }

    private static func nominateChain(
        _ observations: [Observation],
        curve: [Observation],
        lexicon: any Lexicon,
        centers: KeyCenters,
        costs: DecodeCosts
    ) -> [SearchCandidate] {
        guard observations.allSatisfy({ $0.stroke != 0 }), !observations.isEmpty else { return [] }
        let aimed = AimedSpelling.observations(observations)
        guard let first = aimed.first?.letter, let last = aimed.last?.letter else { return [] }
        var found: [SearchCandidate] = []
        for word in lexicon.endpoints(first: first, last: last) {
            guard let curveCost = PathCheck.cost(word, observations: curve, centers: centers) else { continue }
            guard let rank = lexicon.rank(of: word) else { continue }
            let place = Double(Int(rank) - 1) / Double(max(lexicon.wordCount - 1, 1))
            found.append(SearchCandidate(
                bytes: Array(word.utf8),
                shifts: 0,
                score: -curveCost - costs.frequencyWeight * place
            ))
        }
        return found
    }

    /// Strong letters from either thumb have to appear in order. A crossing does not.
    private static func keepsStrongLetters(_ word: String, chain: [Observation], others: [Observation]) -> Bool {
        let letters = Array(word.utf8)
        let chainLetters = AimedSpelling.observations(chain).map(\.letter)
        let otherLetters = AimedSpelling.observations(others).map(\.letter)
        return containsInOrder(chainLetters, in: letters) && containsInOrder(otherLetters, in: letters)
    }

    private static func containsInOrder(_ required: [UInt8], in letters: [UInt8]) -> Bool {
        var cursor = 0
        for letter in required {
            guard let index = letters[cursor...].firstIndex(of: letter) else { return false }
            cursor = index + 1
        }
        return true
    }
}
