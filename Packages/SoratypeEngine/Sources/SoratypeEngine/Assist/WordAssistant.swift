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

    public mutating func preview(_ result: DecodeResult, now: Int, costs: DecodeCosts) -> Strip {
        let readings = result.readings
        let choice = stickyLeader(readings, now: now, margin: costs.unsureMargin, hold: costs.stickyLeaderMilliseconds)
        var chips: [Chip] = []
        if let pinned {
            chips.append(Chip(text: pinned, role: .leader))
            for reading in readings where reading.text.lowercased() != pinned.lowercased() && chips.count < 3 {
                chips.append(Chip(text: reading.text, role: .alternative))
            }
        } else {
            for reading in readings.prefix(3) {
                let role: ChipRole = reading.text == choice ? .leader : .alternative
                chips.append(Chip(text: reading.text, role: role))
            }
        }
        let close = readings.count > 1 && abs(readings[0].score - readings[1].score) <= costs.unsureMargin
        let highlighted = close || chips.isEmpty ? nil : chips.firstIndex { $0.role == .leader }
        strip = Strip(chips: chips, highlighted: highlighted, preview: true)
        return strip
    }

    public mutating func landed(_ result: DecodeResult, aimed: String, suffix: String?, follower: String?) -> Strip {
        pinned = nil
        leader = result.top ?? aimed
        var chips: [Chip] = []
        if let top = result.top {
            chips.append(Chip(text: top, role: .leader))
        }
        if !aimed.isEmpty, aimed.lowercased() != (result.top ?? "").lowercased(), chips.count < 3 {
            chips.append(Chip(text: aimed, role: .aimed))
        }
        if let suffix, chips.count < 3 {
            chips.append(Chip(text: suffix, role: .suffix))
        }
        for reading in result.readings.dropFirst() where chips.count < 3 {
            chips.append(Chip(text: reading.text, role: .alternative))
        }
        if let follower, chips.count < 3, follower.lowercased() != (result.top ?? "").lowercased() {
            chips.append(Chip(text: follower, role: .follower))
        }
        strip = Strip(chips: chips, highlighted: chips.isEmpty ? nil : 0, preview: false)
        return strip
    }

    public mutating func promote(_ index: Int) -> String? {
        guard strip.chips.indices.contains(index) else { return nil }
        let chip = strip.chips[index]
        guard chip.role != .suffix, chip.role != .follower else { return nil }
        pinned = chip.text
        leader = chip.text
        var chips = strip.chips
        chips.remove(at: index)
        chips.insert(Chip(text: chip.text, role: .leader), at: 0)
        strip = Strip(chips: chips, highlighted: 0, preview: strip.preview)
        return chip.text
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
