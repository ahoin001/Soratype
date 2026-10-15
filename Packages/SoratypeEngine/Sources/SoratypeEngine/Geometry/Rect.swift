public struct Rect: Sendable, Equatable, Hashable {
    public var origin: Point
    public var size: Size

    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.origin = Point(x: x, y: y)
        self.size = Size(width: width, height: height)
    }

    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }
    public var center: Point {
        Point(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
    }

    public func contains(_ point: Point, slop: Double = 0) -> Bool {
        point.x >= minX - slop
            && point.x <= maxX + slop
            && point.y >= minY - slop
            && point.y <= maxY + slop
    }

    public func distanceOutside(_ point: Point) -> Double {
        let dx = max(minX - point.x, point.x - maxX, 0)
        let dy = max(minY - point.y, point.y - maxY, 0)
        return (dx * dx + dy * dy).squareRoot()
    }
}
