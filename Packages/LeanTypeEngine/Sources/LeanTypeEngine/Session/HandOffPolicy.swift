public struct HandOffPolicy: Sendable, Equatable {
    public var enabled: Bool
    public var milliseconds: Int

    public init(settings: EngineSettings) {
        enabled = settings.handoffGraceEnabled
        milliseconds = settings.handoffGraceMilliseconds
    }

    /// A fragment is strong only when the letters actually hit are themselves a solid lexicon word.
    /// Unsure never decides whether the next gesture joins.
    public func isWeak(_ result: DecodeResult, lexicon: any Lexicon) -> Bool {
        let aimed = result.aimed.lowercased()
        guard lexicon.contains(aimed) else { return true }
        guard let top = result.readings.first, !result.budgetExhausted else { return true }
        if top.score <= DecodeCosts.standard.weakScore { return true }
        return top.text.lowercased() != aimed
    }
}
