public struct WordAssistant: Sendable {
    public private(set) var strip = Strip.empty
    private var leader = ""
    private var leaderSince = 0
    private var pending: String?
    private var pendingSince = 0
    public var pinned: String?

    public init() {}

    public mutating func reset() {
        leader = ""
        pending = nil
        pinned = nil
        strip = .empty
    }

    public mutating func preview(
        _ result: DecodeResult,
        now: Int,
        costs: DecodeCosts,
        extras: [Chip] = []
    ) -> Strip {
        let near = readingsNearTheLeader(result.readings)
        let choice = stickyLeader(near, now: now, margin: costs.unsureMargin, hold: costs.stickyLeaderMilliseconds)
        var chips: [Chip] = []
        if let pinned {
            chips.append(Chip(text: pinned, role: .leader))
            for reading in near where reading.text.lowercased() != pinned.lowercased() {
                chips.append(Chip(text: reading.text, role: .alternative))
            }
        } else if let primary = near.first(where: { $0.text.lowercased() == choice.lowercased() }) ?? near.first {
            chips.append(Chip(text: primary.text, role: .leader))
            for reading in near where reading.text.lowercased() != primary.text.lowercased() {
                chips.append(Chip(text: reading.text, role: .alternative))
            }
        }
        chips.append(contentsOf: extras)
        let close = near.count > 1 && abs(near[0].score - near[1].score) <= costs.unsureMargin
        return assemble(chips, preview: true, highlighted: close ? nil : chips.firstIndex { $0.role == .leader })
    }

    public mutating func landed(committed: String, extras: [Chip]) -> Strip {
        pinned = nil
        leader = committed
        var chips: [Chip] = []
        if !committed.isEmpty {
            chips.append(Chip(text: committed, role: .context))
        }
        chips.append(contentsOf: extras)
        return assemble(chips, preview: false, highlighted: chips.isEmpty ? nil : 0)
    }

    /// The next stroke has started. Drop the previous next-word bar before its decode arrives.
    public mutating func beginDecision() -> Strip {
        pinned = nil
        pending = nil
        strip = Strip(preview: true)
        return strip
    }

    /// The deleted word and the other readings, so a tap can put one back.
    public mutating func undoOffer(_ words: [String]) -> Strip {
        pinned = nil
        var seen = Set<String>()
        var chips: [Chip] = []
        for raw in words {
            let key = raw.lowercased()
            guard !raw.isEmpty, seen.insert(key).inserted else { continue }
            chips.append(Chip(text: raw, role: chips.isEmpty ? .follower : .alternative))
            if chips.count == 3 { break }
        }
        leader = chips.first?.text ?? ""
        return assemble(chips, preview: false, highlighted: chips.isEmpty ? nil : 0)
    }

    /// Keeps the first three distinct chips. Later candidates fill slots the row would otherwise leave empty.
    private mutating func assemble(_ incoming: [Chip], preview: Bool, highlighted: Int?) -> Strip {
        var chips: [Chip] = []
        var seen = Set<String>()
        for chip in incoming {
            let key = chip.text.lowercased()
            guard !chip.text.isEmpty, seen.insert(key).inserted else { continue }
            chips.append(chip)
            if chips.count == 3 { break }
        }
        let index = highlighted.flatMap { chips.indices.contains($0) ? $0 : nil }
        strip = Strip(chips: chips, highlighted: index, preview: preview)
        return strip
    }

    private func readingsNearTheLeader(_ readings: [Reading]) -> [Reading] {
        guard let top = readings.first else { return [] }
        return readings.filter { top.score - $0.score <= 4 }
    }

    public mutating func promote(_ index: Int) -> String? {
        guard strip.chips.indices.contains(index) else { return nil }
        let chip = strip.chips[index]
        guard chip.role != .suffix, chip.role != .follower, chip.role != .context else { return nil }
        pinned = chip.text
        leader = chip.text
        var chips = strip.chips
        chips.remove(at: index)
        chips.insert(Chip(text: chip.text, role: .leader), at: 0)
        strip = Strip(chips: chips, highlighted: 0, preview: strip.preview)
        return chip.text
    }

    public mutating func remove(_ index: Int) -> String? {
        guard strip.chips.indices.contains(index) else { return nil }
        let text = strip.chips[index].text
        var chips = strip.chips
        chips.remove(at: index)
        var highlighted = strip.highlighted
        if let current = highlighted, current >= chips.count {
            highlighted = chips.isEmpty ? nil : 0
        }
        strip = Strip(chips: chips, highlighted: highlighted, preview: strip.preview)
        return text
    }

    private mutating func stickyLeader(_ readings: [Reading], now: Int, margin: Double, hold: Int) -> String {
        guard let top = readings.first else { return leader }
        if leader.isEmpty {
            leader = top.text
            leaderSince = now
            return leader
        }
        if top.text.lowercased() == leader.lowercased() {
            pending = nil
            return leader
        }
        let current = readings.first { $0.text.lowercased() == leader.lowercased() }?.score ?? (top.score - margin - 1)
        if top.score >= current + margin {
            if pending?.lowercased() != top.text.lowercased() {
                pending = top.text
                pendingSince = now
            }
            if now - pendingSince >= hold {
                leader = top.text
                leaderSince = now
                pending = nil
            }
        } else {
            pending = nil
        }
        return leader
    }
}
