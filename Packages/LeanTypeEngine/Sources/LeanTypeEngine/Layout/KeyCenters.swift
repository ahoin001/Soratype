public struct KeyCenters: Sendable, Equatable {
    public var xs: [Double]
    public var ys: [Double]
    public var present: [Bool]
    public var width: Double
    public var height: Double

    public init(xs: [Double], ys: [Double], present: [Bool], width: Double, height: Double) {
        self.xs = xs
        self.ys = ys
        self.present = present
        self.width = width
        self.height = height
    }

    public static func index(for byte: UInt8) -> Int {
        if byte == 39 { return 26 }
        if (97...122).contains(byte) { return Int(byte - 97) }
        return 27
    }

    public func center(_ byte: UInt8) -> Point? {
        let index = Self.index(for: byte)
        guard index < present.count, present[index] else { return nil }
        return Point(x: xs[index], y: ys[index])
    }

    public func neighborBytes(of byte: UInt8) -> [UInt8] {
        guard let origin = center(byte) else { return [] }
        let limit = max(width, height) * 1.35
        var found: [UInt8] = []
        for candidate in UInt8(97)...UInt8(122) {
            guard candidate != byte, let point = center(candidate) else { continue }
            if origin.distance(to: point) <= limit {
                found.append(candidate)
            }
        }
        return found
    }
}
