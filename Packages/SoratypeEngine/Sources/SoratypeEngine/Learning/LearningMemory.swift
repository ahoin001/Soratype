import Foundation

public struct LearningMemory: Sendable, Equatable, Codable {
    public struct Habit: Sendable, Equatable, Codable {
        public var uses: Int
        public var lastUse: Int
    }

    public struct Prototype: Sendable, Equatable, Codable {
        public var word: String
        public var aimed: String
        public var start: UInt8
        public var end: UInt8
        public var length: Int
    }

    public struct Refusal: Sendable, Equatable, Codable {
        public var word: String
        public var aimed: String
        public var at: Int
    }

    public struct Bias: Sendable, Equatable, Codable {
        public var dx: Double
        public var dy: Double
        public var samples: Int

        public static let zero = Bias(dx: 0, dy: 0, samples: 0)
    }

    public var habits: [String: Habit]
    public var pairs: [String: Int]
    public var prototypes: [Prototype]
    public var rejections: [String: String]
    public var refusals: [Refusal]
    public var blocklist: [String]
    public var personal: [String: Int]
    public var leftBias: Bias
    public var rightBias: Bias
    public var pendingRefusal: Refusal?
    public var impressions: [String: Int]

    public init(
        habits: [String: Habit] = [:],
        pairs: [String: Int] = [:],
        prototypes: [Prototype] = [],
        rejections: [String: String] = [:],
        refusals: [Refusal] = [],
        blocklist: [String] = [],
        personal: [String: Int] = [:],
        leftBias: Bias = .zero,
        rightBias: Bias = .zero,
        pendingRefusal: Refusal? = nil,
        impressions: [String: Int] = [:]
    ) {
        self.habits = habits
        self.pairs = pairs
        self.prototypes = prototypes
        self.rejections = rejections
        self.refusals = refusals
        self.blocklist = blocklist
        self.personal = personal
        self.leftBias = leftBias
        self.rightBias = rightBias
        self.pendingRefusal = pendingRefusal
        self.impressions = impressions
    }

    private enum CodingKeys: String, CodingKey {
        case habits, pairs, prototypes, rejections, refusals, blocklist, personal
        case leftBias, rightBias, pendingRefusal, impressions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            habits: try container.decodeIfPresent([String: Habit].self, forKey: .habits) ?? [:],
            pairs: try container.decodeIfPresent([String: Int].self, forKey: .pairs) ?? [:],
            prototypes: try container.decodeIfPresent([Prototype].self, forKey: .prototypes) ?? [],
            rejections: try container.decodeIfPresent([String: String].self, forKey: .rejections) ?? [:],
            refusals: try container.decodeIfPresent([Refusal].self, forKey: .refusals) ?? [],
            blocklist: try container.decodeIfPresent([String].self, forKey: .blocklist) ?? [],
            personal: try container.decodeIfPresent([String: Int].self, forKey: .personal) ?? [:],
            leftBias: try container.decodeIfPresent(Bias.self, forKey: .leftBias) ?? .zero,
            rightBias: try container.decodeIfPresent(Bias.self, forKey: .rightBias) ?? .zero,
            pendingRefusal: try container.decodeIfPresent(Refusal.self, forKey: .pendingRefusal),
            impressions: try container.decodeIfPresent([String: Int].self, forKey: .impressions) ?? [:]
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(habits, forKey: .habits)
        try container.encode(pairs, forKey: .pairs)
        try container.encode(prototypes, forKey: .prototypes)
        try container.encode(rejections, forKey: .rejections)
        try container.encode(refusals, forKey: .refusals)
        try container.encode(blocklist, forKey: .blocklist)
        try container.encode(personal, forKey: .personal)
        try container.encode(leftBias, forKey: .leftBias)
        try container.encode(rightBias, forKey: .rightBias)
        try container.encodeIfPresent(pendingRefusal, forKey: .pendingRefusal)
        try container.encode(impressions, forKey: .impressions)
    }

    public static let empty = LearningMemory()

    public static func skipsLearning(_ word: String) -> Bool {
        let token = word.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.contains("@") || token.contains("://") || token.contains("www.") { return true }
        if token.range(of: #"\d{4,}"#, options: .regularExpression) != nil { return true }
        return false
    }

    public func shouldFade(_ word: String) -> Bool {
        (impressions[word.lowercased()] ?? 0) >= 3
    }

    public func snapshot(previousWord: String?, now: Int, observations: [Observation]) -> LearningSnapshot {
        var habitBonus: [String: Double] = [:]
        for (word, habit) in habits {
            let age = now - habit.lastUse
            let day = 86_400_000
            if habit.uses == 0 || age > 45 * day { continue }
            let bonus: Double
            if age <= 7 * day {
                bonus = 0.45
            } else {
                let fade = Double(age - 7 * day) / Double(38 * day)
                bonus = max(0, 0.45 * (1 - fade))
            }
            habitBonus[word] = bonus
        }
        var pairBonus: [String: Double] = [:]
        if let previousWord {
            let prefix = previousWord.lowercased() + "\t"
            for (key, count) in pairs where key.hasPrefix(prefix) && count > 0 {
                pairBonus[key] = 0.45
            }
        }
        var prototypeBonus: [String: Double] = [:]
        let aimed = AimedSpelling.observations(observations)
        if let first = aimed.first?.letter, let last = aimed.last?.letter {
            for prototype in prototypes where prototype.start == first && prototype.end == last && abs(prototype.length - aimed.count) <= 2 {
                prototypeBonus[prototype.word] = 1.2
            }
        }
        var demoted: [String: Double] = [:]
        for refusal in refusals {
            demoted[refusal.word] = 1.5
        }
        for (word, penalty) in demoted {
            habitBonus[word] = (habitBonus[word] ?? 0) - penalty
        }
        return LearningSnapshot(
            habits: habitBonus,
            pairs: pairBonus,
            blocked: Set(blocklist),
            rejections: rejections,
            prototypes: prototypeBonus,
            personal: personal
        )
    }

    public func follower(of previous: String) -> String? {
        let prefix = previous.lowercased() + "\t"
        return pairs
            .filter { $0.key.hasPrefix(prefix) }
            .max { $0.value < $1.value }?
            .key
            .split(separator: "\t")
            .last
            .map(String.init)
    }

    public mutating func noteAccept(_ word: String, previous: String?, now: Int) {
        guard !Self.skipsLearning(word) else { return }
        let key = word.lowercased()
        impressions[key] = 0
        var habit = habits[key] ?? Habit(uses: 0, lastUse: now)
        habit.uses += 1
        habit.lastUse = now
        habits[key] = habit
        trim(&habits, limit: 400) { $0.value.lastUse }
        personal[key, default: 0] += 1
        trim(&personal, limit: 1_000) { $0.value }
        if let previous {
            let pair = previous.lowercased() + "\t" + key
            pairs[pair, default: 0] += 1
            trim(&pairs, limit: 400) { $0.value }
        }
        if let pending = pendingRefusal, now - pending.at <= 10_000, pending.word != key {
            var refusal = pending
            refusal.word = pending.word
            refusals.append(Refusal(word: pending.word, aimed: pending.aimed, at: now))
            if refusals.count > 12 { refusals.removeFirst(refusals.count - 12) }
        }
        pendingRefusal = nil
    }

    public mutating func noteSwipeRemoval(word: String, aimed: String, now: Int) {
        pendingRefusal = Refusal(word: word.lowercased(), aimed: aimed.lowercased(), at: now)
    }

    public mutating func noteChoice(word: String, aimed: String, observations: [Observation]) {
        impressions[word.lowercased()] = 0
        let kept = AimedSpelling.observations(observations)
        guard let first = kept.first?.letter, let last = kept.last?.letter else { return }
        prototypes.append(Prototype(
            word: word.lowercased(),
            aimed: aimed.lowercased(),
            start: first,
            end: last,
            length: kept.count
        ))
        if prototypes.count > 160 { prototypes.removeFirst(prototypes.count - 160) }
        if word.lowercased() != aimed.lowercased() {
            rejections[aimed.lowercased()] = word.lowercased()
        }
        if rejections.count > 200, let oldest = rejections.keys.first {
            rejections.removeValue(forKey: oldest)
        }
    }

    public mutating func noteImpression(_ word: String) {
        let key = word.lowercased()
        guard !shouldFade(key) else { return }
        impressions[key, default: 0] += 1
    }

    public mutating func noteReject(_ word: String) {
        let key = word.lowercased()
        impressions[key] = 3
        guard !blocklist.contains(key) else { return }
        blocklist.append(key)
        if blocklist.count > 300 {
            blocklist.removeFirst(blocklist.count - 300)
        }
    }

    public mutating func allow(_ word: String) {
        let key = word.lowercased()
        blocklist.removeAll { $0 == key }
        impressions[key] = 0
    }

    public mutating func forget(_ word: String) {
        let key = word.lowercased()
        habits[key] = nil
        personal[key] = nil
        impressions[key] = nil
        rejections[key] = nil
        blocklist.removeAll { $0 == key }
        prototypes.removeAll { $0.word == key }
        pairs = pairs.filter { !$0.key.hasSuffix("\t" + key) && !$0.key.hasPrefix(key + "\t") }
    }

    public mutating func noteBias(thumb: Thumb, dx: Double, dy: Double, limit: Double) {
        var bias = thumb == .left ? leftBias : rightBias
        let count = bias.samples + 1
        bias.dx = min(limit, max(-limit, (bias.dx * Double(bias.samples) + dx) / Double(count)))
        bias.dy = min(limit, max(-limit, (bias.dy * Double(bias.samples) + dy) / Double(count)))
        bias.samples = min(count, 80)
        if thumb == .left { leftBias = bias } else { rightBias = bias }
    }

    public func bias(for thumb: Thumb) -> Bias {
        thumb == .left ? leftBias : rightBias
    }

    private func trim<Value, Score: Comparable>(
        _ table: inout [String: Value],
        limit: Int,
        score: (Dictionary<String, Value>.Element) -> Score
    ) {
        guard table.count > limit else { return }
        let sorted = table.sorted { score($0) < score($1) }
        for element in sorted.prefix(table.count - limit) {
            table.removeValue(forKey: element.key)
        }
    }
}

public struct MemoryStore: Sendable {
    public var url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() -> LearningMemory {
        guard let data = try? Data(contentsOf: url),
              let memory = try? JSONDecoder().decode(LearningMemory.self, from: data)
        else { return .empty }
        return memory
    }

    public func save(_ memory: LearningMemory) throws {
        let data = try JSONEncoder().encode(memory)
        try data.write(to: url, options: .atomic)
    }
}
