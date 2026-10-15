public protocol EngineClock: Sendable {
    var now: EngineInstant { get }
}
