struct ChainBeam {
    static func search(
        observations: [Observation],
        lexicon: any Lexicon,
        costs: DecodeCosts,
        deadline: ContinuousClock.Instant
    ) -> (candidates: [SearchCandidate], exhausted: Bool) {
        let left = observations.filter { $0.thumb == .left }.sorted { $0.time < $1.time }
        let right = observations.filter { $0.thumb == .right }.sorted { $0.time < $1.time }
        var exhausted = false
        var found: [SearchCandidate] = []
        for width in costs.beamWidths {
            if ContinuousClock().now >= deadline {
                exhausted = true
                break
            }
            let pass = run(left: left, right: right, width: width, lexicon: lexicon, costs: costs, deadline: deadline)
            exhausted = pass.exhausted
            if !pass.candidates.isEmpty {
                found = pass.candidates
                break
            }
            if exhausted { break }
        }
        return (found, exhausted)
    }

    private static func run(
        left: [Observation],
        right: [Observation],
        width: Int,
        lexicon: any Lexicon,
        costs: DecodeCosts,
        deadline: ContinuousClock.Instant
    ) -> (candidates: [SearchCandidate], exhausted: Bool) {
        let steps = left.count + right.count
        var beam = [ChainHypothesis.root(lexicon.root)]
        if steps == 0 { return ([], false) }
        for _ in 0..<steps {
            if ContinuousClock().now >= deadline { return ([], true) }
            var next: [ChainHypothesis] = []
            next.reserveCapacity(beam.count * 4)
            for hyp in beam {
                if hyp.leftIndex < left.count {
                    let observation = left[hyp.leftIndex]
                    let pending = hyp.rightIndex < right.count ? right[hyp.rightIndex] : nil
                    let penalty = orderCost(taking: observation, pending: pending, costs: costs)
                    if var consumed = Hypothesis(
                        node: hyp.node, bytes: hyp.bytes, shifts: hyp.shifts, score: hyp.score,
                        skipsLeft: hyp.skipsLeft, skipsRight: hyp.skipsRight, doubled: hyp.doubled,
                        crossingSpent: hyp.crossingSpent
                    ).consuming(observation, lexicon: lexicon, costs: costs, double: false) {
                        consumed.score -= penalty
                        next.append(hyp.advanced(with: consumed, side: .left))
                    }
                    if var doubled = Hypothesis(
                        node: hyp.node, bytes: hyp.bytes, shifts: hyp.shifts, score: hyp.score,
                        skipsLeft: hyp.skipsLeft, skipsRight: hyp.skipsRight, doubled: hyp.doubled,
                        crossingSpent: hyp.crossingSpent
                    ).consuming(observation, lexicon: lexicon, costs: costs, double: true) {
                        doubled.score -= penalty
                        next.append(hyp.advanced(with: doubled, side: .left))
                    }
                    if let skipped = Hypothesis(
                        node: hyp.node, bytes: hyp.bytes, shifts: hyp.shifts, score: hyp.score,
                        skipsLeft: hyp.skipsLeft, skipsRight: hyp.skipsRight, doubled: hyp.doubled,
                        crossingSpent: hyp.crossingSpent
                    ).skipping(observation, costs: costs) {
                        next.append(hyp.advanced(with: skipped, side: .left))
                    }
                }
                if hyp.rightIndex < right.count {
                    let observation = right[hyp.rightIndex]
                    let pending = hyp.leftIndex < left.count ? left[hyp.leftIndex] : nil
                    let penalty = orderCost(taking: observation, pending: pending, costs: costs)
                    if var consumed = Hypothesis(
                        node: hyp.node, bytes: hyp.bytes, shifts: hyp.shifts, score: hyp.score,
                        skipsLeft: hyp.skipsLeft, skipsRight: hyp.skipsRight, doubled: hyp.doubled,
                        crossingSpent: hyp.crossingSpent
                    ).consuming(observation, lexicon: lexicon, costs: costs, double: false) {
                        consumed.score -= penalty
                        next.append(hyp.advanced(with: consumed, side: .right))
                    }
                    if var doubled = Hypothesis(
                        node: hyp.node, bytes: hyp.bytes, shifts: hyp.shifts, score: hyp.score,
                        skipsLeft: hyp.skipsLeft, skipsRight: hyp.skipsRight, doubled: hyp.doubled,
                        crossingSpent: hyp.crossingSpent
                    ).consuming(observation, lexicon: lexicon, costs: costs, double: true) {
                        doubled.score -= penalty
                        next.append(hyp.advanced(with: doubled, side: .right))
                    }
                    if let skipped = Hypothesis(
                        node: hyp.node, bytes: hyp.bytes, shifts: hyp.shifts, score: hyp.score,
                        skipsLeft: hyp.skipsLeft, skipsRight: hyp.skipsRight, doubled: hyp.doubled,
                        crossingSpent: hyp.crossingSpent
                    ).skipping(observation, costs: costs) {
                        next.append(hyp.advanced(with: skipped, side: .right))
                    }
                }
            }
            beam = Array(next.sorted { $0.score > $1.score }.prefix(width))
            if beam.isEmpty { break }
        }
        let finished = beam.filter { $0.leftIndex == left.count && $0.rightIndex == right.count }
        let candidates = finished.compactMap { hyp -> SearchCandidate? in
            Hypothesis(
                node: hyp.node, bytes: hyp.bytes, shifts: hyp.shifts, score: hyp.score,
                skipsLeft: hyp.skipsLeft, skipsRight: hyp.skipsRight, doubled: hyp.doubled,
                crossingSpent: hyp.crossingSpent
            ).finished(in: lexicon, costs: costs)
        }
        return (candidates, false)
    }

    private static func orderCost(taking: Observation, pending: Observation?, costs: DecodeCosts) -> Double {
        guard let pending, taking.time > pending.time else { return 0 }
        let seconds = Double(taking.time - pending.time) / 1000
        var cost = min(costs.crossCostCap, costs.crossCostPerSecond * seconds)
        if taking.otherThumbDown { cost /= 2 }
        return cost
    }
}

private struct ChainHypothesis: Sendable {
    var node: LexiconNode
    var bytes: [UInt8]
    var shifts: UInt64
    var score: Double
    var skipsLeft: Int
    var skipsRight: Int
    var doubled: Bool
    var crossingSpent: Double
    var leftIndex: Int
    var rightIndex: Int

    static func root(_ node: LexiconNode) -> ChainHypothesis {
        ChainHypothesis(
            node: node, bytes: [], shifts: 0, score: 0,
            skipsLeft: 0, skipsRight: 0, doubled: false, crossingSpent: 0,
            leftIndex: 0, rightIndex: 0
        )
    }

    func advanced(with hyp: Hypothesis, side: Thumb) -> ChainHypothesis {
        var copy = self
        copy.node = hyp.node
        copy.bytes = hyp.bytes
        copy.shifts = hyp.shifts
        copy.score = hyp.score
        copy.skipsLeft = hyp.skipsLeft
        copy.skipsRight = hyp.skipsRight
        copy.doubled = hyp.doubled
        copy.crossingSpent = hyp.crossingSpent
        if side == .left {
            copy.leftIndex += 1
        } else {
            copy.rightIndex += 1
        }
        return copy
    }
}
