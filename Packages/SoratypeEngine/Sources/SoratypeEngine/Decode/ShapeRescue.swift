enum ShapeRescue {
    static func nominate(
        observations: [Observation],
        lexicon: any Lexicon,
        centers: KeyCenters,
        costs: DecodeCosts
    ) -> [SearchCandidate] {
        let strokes = Set(observations.map(\.stroke))
        guard observations.allSatisfy({ $0.stroke != 0 }), strokes.count == 1 else { return [] }
        let aimed = AimedSpelling.observations(observations)
        guard let first = aimed.first?.letter, let last = aimed.last?.letter else { return [] }
        var found: [SearchCandidate] = []
        for word in lexicon.endpoints(first: first, last: last) {
            guard PathCheck.explains(word, observations: observations, centers: centers) else { continue }
            guard let rank = lexicon.rank(of: word) else { continue }
            let place = Double(Int(rank) - 1) / Double(max(lexicon.wordCount - 1, 1))
            let bytes = Array(word.utf8)
            found.append(SearchCandidate(
                bytes: bytes,
                shifts: 0,
                score: -0.8 - costs.frequencyWeight * place
            ))
        }
        return found
    }
}
