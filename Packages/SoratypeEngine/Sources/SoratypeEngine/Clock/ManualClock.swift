public struct ManualClock: EngineClock, Sendable {
    public var now: EngineInstant

    public init(now: EngineInstant = .zero) {
        self.now = now
    }

    public mutating func advance(by milliseconds: Int) {
        now = now.advanced(by: milliseconds)
    }
}
