enum PathCheck {
    /// Mean distance, in key sizes, from each letter to the traced curve.
    /// Nil when a letter cannot be placed in order.
    static func cost(_ word: String, observations: [Observation], centers: KeyCenters) -> Double? {
        let ordered = observations.sorted { $0.time < $1.time }
        guard ordered.count >= 2 else { return 0 }
        let samples = samples(along: ordered)
        let bytes = Array(word.lowercased().utf8)
        guard !bytes.isEmpty else { return nil }
        let scale = max(max(centers.width, centers.height), 1)
        let limit = scale * 1.35
        var cursor = 0
        var total = 0.0
        for byte in bytes {
            guard let center = centers.center(byte) else { return nil }
            var index = cursor
            var opened = false
            var nearest = Double.greatestFiniteMagnitude
            var firstMatch = cursor
            while index < samples.count {
                let distance = samples[index].distance(to: center)
                if distance <= limit {
                    if !opened { firstMatch = index }
                    opened = true
                    nearest = min(nearest, distance)
                    index += 1
                    continue
                }
                if opened { break }
                index += 1
            }
            guard opened else { return nil }
            total += nearest / scale
            cursor = firstMatch + 1
        }
        return total / Double(bytes.count)
    }

    private static func samples(along ordered: [Observation]) -> [Point] {
        var samples: [Point] = []
        samples.reserveCapacity(ordered.count * 8)
        for index in 0..<(ordered.count - 1) {
            let start = ordered[index].point
            let end = ordered[index + 1].point
            for step in 0..<8 {
                let t = Double(step) / 8
                samples.append(Point(
                    x: start.x + (end.x - start.x) * t,
                    y: start.y + (end.y - start.y) * t
                ))
            }
        }
        if let last = ordered.last { samples.append(last.point) }
        return samples
    }
}
