public enum AlignmentPathMatcher {
    public static func match(_ request: DecodeRequest) -> DecodeResult {
        let aimed = AimedSpelling.text(from: request.observations)
        guard !request.observations.isEmpty else {
            return DecodeResult(readings: [], aimed: "", unsure: false, budgetExhausted: false)
        }
        let deadline = ContinuousClock().now.advanced(by: .milliseconds(request.budgetMilliseconds))
        let bothThumbs = request.observations.contains { $0.thumb == .left }
            && request.observations.contains { $0.thumb == .right }
        let searched = bothThumbs
            ? ChainBeam.search(
                observations: request.observations,
                lexicon: request.lexicon,
                costs: request.costs,
                deadline: deadline
            )
            : BeamSearch.search(
                observations: request.observations,
                lexicon: request.lexicon,
                costs: request.costs,
                deadline: deadline
            )
        var pool = searched.candidates
        if ContinuousClock().now < deadline {
            pool += ShapeRescue.nominate(
                observations: request.observations,
                lexicon: request.lexicon,
                centers: request.centers,
                costs: request.costs
            )
        }
        var readings = decorate(pool, request: request, aimed: aimed)
        let needsRecovery = readings.isEmpty
            || readings[0].score <= request.costs.weakScore
            || (readings.count > 1 && abs(readings[0].score - readings[1].score) <= 0.05)
        if needsRecovery, ContinuousClock().now < deadline {
            let edits = RecoveryPass.edits(
                observations: request.observations,
                lexicon: request.lexicon,
                centers: request.centers,
                costs: request.costs
            )
            readings = decorate(pool + edits, request: request, aimed: aimed)
        }
        if readings.isEmpty {
            return DecodeResult.aimedOnly(aimed, exhausted: searched.exhausted || ContinuousClock().now >= deadline)
        }
        readings = preferAimed(readings, aimed: aimed, request: request)
        readings = applyRejection(readings, aimed: aimed, request: request)
        readings = leadingTapSkip(readings, request: request, aimed: aimed)
        let unsure = readings.count > 1 && abs(readings[0].score - readings[1].score) <= request.costs.unsureMargin
        return DecodeResult(
            readings: Array(readings.prefix(8)),
            aimed: aimed,
            unsure: unsure,
            budgetExhausted: searched.exhausted && pool.isEmpty
        )
    }

    private static func decorate(_ candidates: [SearchCandidate], request: DecodeRequest, aimed: String) -> [Reading] {
        var best: [String: Reading] = [:]
        for candidate in candidates {
            let key = candidate.lowercase
            let aimedHit = key == aimed.lowercased()
            if request.learning.blocked.contains(key), !aimedHit { continue }
            if request.lexicon.isOffensive(key), !aimedHit { continue }
            let uses = request.learning.personal[key] ?? 0
            let known = request.lexicon.contains(key) || uses >= 3
            guard known || uses >= 2 else { continue }
            var score = candidate.score
            score += min(request.costs.habitCap, request.learning.habits[key] ?? 0)
            if let previous = request.previousWord?.lowercased() {
                let learned = request.learning.pairs["\(previous)\t\(key)"] ?? 0
                if learned != 0 {
                    score += learned
                } else if request.lexicon.followers(of: previous).contains(key) {
                    score += request.costs.pairBonus
                }
            }
            score += request.learning.prototypes[key] ?? 0
            let reading = Reading(text: candidate.display, score: score, aimed: key == aimed.lowercased())
            if let existing = best[key], existing.score >= reading.score { continue }
            best[key] = reading
        }
        return Array(best.values).sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.text < rhs.text }
            return lhs.score > rhs.score
        }
    }

    private static func preferAimed(_ readings: [Reading], aimed: String, request: DecodeRequest) -> [Reading] {
        let key = aimed.lowercased()
        guard request.lexicon.contains(key) || (request.learning.personal[key] ?? 0) >= 3 else {
            return readings
        }
        var readings = readings
        let existing = readings.first { $0.text.lowercased() == key }
        let aimedScore = existing?.score ?? 0
        guard let best = readings.first else {
            return [Reading(text: aimed, score: aimedScore, aimed: true)]
        }
        guard best.text.lowercased() != key, best.score - aimedScore <= request.costs.aimedMargin else {
            return readings
        }
        if let index = readings.firstIndex(where: { $0.text.lowercased() == key }) {
            let chosen = readings.remove(at: index)
            readings.insert(Reading(text: chosen.text, score: chosen.score, aimed: true), at: 0)
        } else {
            readings.insert(Reading(text: aimed, score: aimedScore, aimed: true), at: 0)
        }
        return readings
    }

    private static func applyRejection(_ readings: [Reading], aimed: String, request: DecodeRequest) -> [Reading] {
        guard let insisted = request.learning.rejections[aimed.lowercased()] else { return readings }
        var readings = readings
        if let index = readings.firstIndex(where: { $0.text.lowercased() == insisted }) {
            let chosen = readings.remove(at: index)
            readings.insert(chosen, at: 0)
            return readings
        }
        guard request.lexicon.contains(insisted) else { return readings }
        readings.insert(Reading(text: insisted, score: (readings.first?.score ?? 0) + 0.1, aimed: false), at: 0)
        return readings
    }

    /// A stray first tap must not hide a confident stroke word. Both readings stay.
    /// The tap has to be finished and earliest by time. A letter still held, or a tap that lands during that hold, stays.
    private static func leadingTapSkip(_ readings: [Reading], request: DecodeRequest, aimed: String) -> [Reading] {
        let ordered = request.observations.sorted { $0.time < $1.time }
        guard let first = ordered.first, first.kind == .tap, first.stroke == 0, first.lifted else { return readings }
        let rest = ordered.dropFirst()
        guard let strokeID = rest.first?.stroke, strokeID != 0 else { return readings }
        guard rest.allSatisfy({ $0.stroke == strokeID && $0.time > first.liftTime }) else { return readings }
        let strokeWord = AimedSpelling.text(from: Array(rest))
        let key = strokeWord.lowercased()
        guard request.lexicon.contains(key), !request.lexicon.isOffensive(key) else { return readings }
        let joinedIsWord = request.lexicon.contains(aimed.lowercased())
        guard !joinedIsWord else { return readings }
        var readings = readings
        if let index = readings.firstIndex(where: { $0.text.lowercased() == key }) {
            let chosen = readings.remove(at: index)
            readings.insert(Reading(text: chosen.text, score: max(chosen.score, 0.2), aimed: false), at: 0)
        } else {
            readings.insert(Reading(text: strokeWord, score: 0.2, aimed: false), at: 0)
        }
        if !aimed.isEmpty, !readings.contains(where: { $0.text.lowercased() == aimed.lowercased() }) {
            readings.append(Reading(text: aimed, score: -4, aimed: true))
        }
        return readings
    }
}
