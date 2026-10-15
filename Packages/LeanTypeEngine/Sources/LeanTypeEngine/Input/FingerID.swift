public struct FingerID: Sendable, Hashable, Equatable {
    public var raw: Int

    public init(_ raw: Int) {
        self.raw = raw
    }
}
