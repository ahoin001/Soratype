public struct EngineInstant: Sendable, Equatable, Hashable, Comparable {
    public var milliseconds: Int

    public init(milliseconds: Int) {
        self.milliseconds = milliseconds
    }

    public static let zero = EngineInstant(milliseconds: 0)

    public static func < (lhs: EngineInstant, rhs: EngineInstant) -> Bool {
        lhs.milliseconds < rhs.milliseconds
    }

    public func advanced(by milliseconds: Int) -> EngineInstant {
        EngineInstant(milliseconds: self.milliseconds + milliseconds)
    }

    public func duration(since earlier: EngineInstant) -> Int {
        milliseconds - earlier.milliseconds
    }
}
