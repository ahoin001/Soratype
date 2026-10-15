public struct TouchSample: Sendable, Equatable {
    public var time: EngineInstant
    public var finger: FingerID
    public var phase: TouchPhase
    public var point: Point
    public var key: PlacedKey?

    public init(
        time: EngineInstant,
        finger: FingerID,
        phase: TouchPhase,
        point: Point,
        key: PlacedKey?
    ) {
        self.time = time
        self.finger = finger
        self.phase = phase
        self.point = point
        self.key = key
    }
}
