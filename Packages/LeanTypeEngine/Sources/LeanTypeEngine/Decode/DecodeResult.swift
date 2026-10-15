public struct Reading: Sendable, Equatable {
    public var text: String
    public var score: Double
    public var aimed: Bool

    public init(text: String, score: Double, aimed: Bool) {
        self.text = text
        self.score = score
        self.aimed = aimed
    }
}

public struct DecodeResult: Sendable, Equatable {
    public var readings: [Reading]
    public var aimed: String
    public var unsure: Bool
    public var budgetExhausted: Bool

    public init(readings: [Reading], aimed: String, unsure: Bool, budgetExhausted: Bool) {
        self.readings = readings
        self.aimed = aimed
        self.unsure = unsure
        self.budgetExhausted = budgetExhausted
    }

    public var top: String? { readings.first?.text }

    public static func aimedOnly(_ text: String, exhausted: Bool) -> DecodeResult {
        DecodeResult(
            readings: text.isEmpty ? [] : [Reading(text: text, score: -8, aimed: true)],
            aimed: text,
            unsure: false,
            budgetExhausted: exhausted
        )
    }
}
