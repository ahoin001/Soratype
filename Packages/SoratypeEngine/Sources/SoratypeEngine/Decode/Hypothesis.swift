struct Hypothesis: Sendable {
    var node: LexiconNode
    var bytes: [UInt8]
    var shifts: UInt64
    var score: Double
    var skipsLeft: Int
    var skipsRight: Int
    var doubled: Bool

    static func make(node: LexiconNode) -> Hypothesis {
        Hypothesis(node: node, bytes: [], shifts: 0, score: 0, skipsLeft: 0, skipsRight: 0, doubled: false)
    }

    func consuming(
        _ observation: Observation,
        lexicon: any Lexicon,
        costs: DecodeCosts,
        double: Bool
    ) -> Hypothesis? {
        if double, doubled || observation.isDwell { return nil }
        guard var node = lexicon.child(node, observation.letter) else { return nil }
        var bytes = bytes
        bytes.reserveCapacity(self.bytes.count + 2)
        bytes.append(observation.letter)
        var shifts = shifts
        if observation.shifted, bytes.count <= 64 {
            shifts |= UInt64(1) << (bytes.count - 1)
        }
        var score = score - SpatialModel.cost(observation, costs: costs)
        var didDouble = doubled
        if double {
            guard let again = lexicon.child(node, observation.letter) else { return nil }
            node = again
            bytes.append(observation.letter)
            if observation.shifted, bytes.count <= 64 {
                shifts |= UInt64(1) << (bytes.count - 1)
            }
            score -= costs.doubleLetter
            didDouble = true
        }
        return Hypothesis(
            node: node,
            bytes: bytes,
            shifts: shifts,
            score: score,
            skipsLeft: skipsLeft,
            skipsRight: skipsRight,
            doubled: didDouble
        )
    }

    func skipping(_ observation: Observation, costs: DecodeCosts) -> Hypothesis? {
        guard let cost = costs.skipCost(observation) else { return nil }
        var left = skipsLeft
        var right = skipsRight
        if costs.countsTowardBudget(observation) {
            if observation.thumb == .left {
                if left >= costs.skipBudgetPerThumb { return nil }
                left += 1
            } else if right >= costs.skipBudgetPerThumb {
                return nil
            } else {
                right += 1
            }
        }
        var copy = self
        copy.score -= cost
        copy.skipsLeft = left
        copy.skipsRight = right
        return copy
    }

    func finished(in lexicon: any Lexicon, costs: DecodeCosts) -> SearchCandidate? {
        let rank = lexicon.rank(node)
        guard rank > 0, lexicon.wordCount > 0 else { return nil }
        let place = Double(Int(rank) - 1) / Double(max(lexicon.wordCount - 1, 1))
        return SearchCandidate(bytes: bytes, shifts: shifts, score: score - costs.frequencyWeight * place)
    }
}
