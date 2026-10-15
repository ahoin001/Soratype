struct BeamSearch {
    static func search(
        observations: [Observation],
        lexicon: any Lexicon,
        costs: DecodeCosts,
        deadline: ContinuousClock.Instant
    ) -> (candidates: [SearchCandidate], exhausted: Bool) {
        let ordered = observations.sorted { $0.time < $1.time }
        var exhausted = false
        var found: [SearchCandidate] = []
        for width in costs.beamWidths {
            if ContinuousClock().now >= deadline {
                exhausted = true
                break
            }
            let pass = run(ordered, width: width, lexicon: lexicon, costs: costs, deadline: deadline)
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
        _ observations: [Observation],
        width: Int,
        lexicon: any Lexicon,
        costs: DecodeCosts,
        deadline: ContinuousClock.Instant
    ) -> (candidates: [SearchCandidate], exhausted: Bool) {
        var layer = [Hypothesis.make(node: lexicon.root)]
        for observation in observations {
            if ContinuousClock().now >= deadline {
                return ([], true)
            }
            var next: [Hypothesis] = []
            next.reserveCapacity(layer.count * 3)
            for hyp in layer {
                if let consumed = hyp.consuming(observation, lexicon: lexicon, costs: costs, double: false) {
                    next.append(consumed)
                }
                if let doubled = hyp.consuming(observation, lexicon: lexicon, costs: costs, double: true) {
                    next.append(doubled)
                }
                if let skipped = hyp.skipping(observation, costs: costs) {
                    next.append(skipped)
                }
            }
            layer = Array(next.sorted { $0.score > $1.score }.prefix(width))
            if layer.isEmpty { break }
        }
        let candidates = layer.compactMap { $0.finished(in: lexicon, costs: costs) }
        return (candidates, false)
    }
}
