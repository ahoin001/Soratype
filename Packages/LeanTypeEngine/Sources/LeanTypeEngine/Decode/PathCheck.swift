enum PathCheck {
    static func explains(_ word: String, observations: [Observation], centers: KeyCenters) -> Bool {
        let ordered = observations.sorted { $0.time < $1.time }
        guard ordered.count >= 2 else { return false }
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
        let bytes = Array(word.lowercased().utf8)
        var cursor = 0
        let limit = max(centers.width, centers.height) * 1.35
        for byte in bytes {
            guard let center = centers.center(byte) else { return false }
            var matched = false
            while cursor < samples.count {
                if samples[cursor].distance(to: center) <= limit {
                    matched = true
                    cursor += 1
                    break
                }
                cursor += 1
            }
            if !matched { return false }
        }
        return true
    }
}
