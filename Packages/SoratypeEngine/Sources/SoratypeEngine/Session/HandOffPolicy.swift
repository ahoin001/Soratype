public struct HandOffPolicy: Sendable, Equatable {
    public var enabled: Bool
    public var milliseconds: Int

    public init(settings: EngineSettings) {
        enabled = settings.handoffGraceEnabled
        milliseconds = settings.handoffGraceMilliseconds
    }

    /// A finished word stays closed. A fragment stays open when the reading invents a letter the finger never touched.
    /// Unsure never decides whether the next gesture joins.
    public func isWeak(_ result: DecodeResult, observations: [Observation], lexicon: any Lexicon) -> Bool {
        guard let top = result.readings.first, !result.budgetExhausted else { return true }
        if top.score <= DecodeCosts.standard.weakScore { return true }
        let word = top.text.lowercased()
        guard lexicon.contains(word) else { return true }
        if word == result.aimed.lowercased() { return false }
        let touched = observations.sorted { $0.time < $1.time }.map(\.letter)
        return !Self.containsInOrder(Array(word.utf8), in: touched)
    }

    private static func containsInOrder(_ required: [UInt8], in letters: [UInt8]) -> Bool {
        var cursor = 0
        for letter in required {
            guard let index = letters[cursor...].firstIndex(of: letter) else { return false }
            cursor = index + 1
        }
        return true
    }
}
