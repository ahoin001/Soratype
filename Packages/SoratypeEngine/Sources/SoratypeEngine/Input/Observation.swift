public struct Observation: Sendable, Equatable {
    public var letter: UInt8
    public var shifted: Bool
    public var kind: ObservationKind
    public var thumb: Thumb
    public var time: Int
    public var x: Double
    public var y: Double
    public var keyX: Double
    public var keyY: Double
    public var keyWidth: Double
    public var keyHeight: Double
    public var centered: Bool
    public var stroke: UInt8
    public var otherThumbDown: Bool
    /// The finger has lifted. A tap still down is not a finished stray tap.
    public var lifted: Bool
    /// Lift timestamp. Zero until the finger lifts. Stroke letters compare against it.
    public var liftTime: Int

    public init(
        letter: UInt8,
        shifted: Bool,
        kind: ObservationKind,
        thumb: Thumb,
        time: Int,
        x: Double,
        y: Double,
        keyX: Double,
        keyY: Double,
        keyWidth: Double,
        keyHeight: Double,
        centered: Bool,
        stroke: UInt8,
        otherThumbDown: Bool,
        lifted: Bool = false,
        liftTime: Int = 0
    ) {
        self.letter = letter
        self.shifted = shifted
        self.kind = kind
        self.thumb = thumb
        self.time = time
        self.x = x
        self.y = y
        self.keyX = keyX
        self.keyY = keyY
        self.keyWidth = keyWidth
        self.keyHeight = keyHeight
        self.centered = centered
        self.stroke = stroke
        self.otherThumbDown = otherThumbDown
        self.lifted = lifted
        self.liftTime = liftTime
    }

    public static let placeholder = Observation(
        letter: 0,
        shifted: false,
        kind: .tap,
        thumb: .left,
        time: 0,
        x: 0,
        y: 0,
        keyX: 0,
        keyY: 0,
        keyWidth: 1,
        keyHeight: 1,
        centered: true,
        stroke: 0,
        otherThumbDown: false,
        lifted: false,
        liftTime: 0
    )

    public var point: Point { Point(x: x, y: y) }
    public var isDwell: Bool { kind == .pin || kind == .rest }
    public var countsInAimedSpelling: Bool {
        switch kind {
        case .anchor, .tap, .pin, .rest: true
        case .crossing, .slip: false
        }
    }
}
