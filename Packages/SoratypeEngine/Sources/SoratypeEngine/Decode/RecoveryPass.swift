enum RecoveryPass {
    static func edits(
        observations: [Observation],
        lexicon: any Lexicon,
        centers: KeyCenters,
        costs: DecodeCosts
    ) -> [SearchCandidate] {
        let aimed = AimedSpelling.observations(observations)
        let bytes = aimed.map(\.letter)
        guard !bytes.isEmpty else { return [] }
        let spatial = aimed.reduce(0) { $0 + SpatialModel.cost($1, costs: costs) }
        var found: [SearchCandidate] = []
        if bytes.count >= 2 {
            for index in 0..<(bytes.count - 1) {
                var swapped = bytes
                swapped.swapAt(index, index + 1)
                consider(swapped, penalty: costs.swapCost + spatial, lexicon: lexicon, costs: costs, into: &found)
            }
            for index in bytes.indices {
                var omitted = bytes
                omitted.remove(at: index)
                consider(omitted, penalty: costs.omissionCost + spatial, lexicon: lexicon, costs: costs, into: &found)
            }
        }
        for index in 0...bytes.count {
            var inserted = bytes
            inserted.insert(39, at: index)
            consider(inserted, penalty: costs.apostropheCost + spatial, lexicon: lexicon, costs: costs, into: &found)
        }
        for (index, byte) in bytes.enumerated() {
            for neighbor in centers.neighborBytes(of: byte) {
                var replaced = bytes
                replaced[index] = neighbor
                consider(replaced, penalty: costs.neighborCost + spatial, lexicon: lexicon, costs: costs, into: &found)
            }
        }
        return found
    }

    private static func consider(
        _ bytes: [UInt8],
        penalty: Double,
        lexicon: any Lexicon,
        costs: DecodeCosts,
        into found: inout [SearchCandidate]
    ) {
        let word = LetterByte.spelling(bytes)
        guard let rank = lexicon.rank(of: word) else { return }
        let place = Double(Int(rank) - 1) / Double(max(lexicon.wordCount - 1, 1))
        found.append(SearchCandidate(
            bytes: bytes,
            shifts: 0,
            score: -penalty - costs.frequencyWeight * place
        ))
    }
}
