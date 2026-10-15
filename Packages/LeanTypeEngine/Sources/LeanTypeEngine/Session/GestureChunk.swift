public struct GestureChunk: Sendable, Equatable {
    public var start: Int
    public var end: Int
    public var isStroke: Bool

    public init(start: Int, end: Int, isStroke: Bool) {
        self.start = start
        self.end = end
        self.isStroke = isStroke
    }
}
