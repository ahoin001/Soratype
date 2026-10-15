/// Decides whether travel is a tap, a hold, or a stroke. Reuses fixed buffers.
public struct GestureSegmenter: Sendable {
    private var slots: InlineArray<5, Slot>
    private var strokeSerial: UInt8 = 1
    public private(set) var activeCount = 0

    public init() {
        slots = InlineArray(repeating: Slot())
    }

    public var hasActiveStroke: Bool {
        for index in 0..<5 where slots[index].occupied && slots[index].isStroke {
            return true
        }
        return false
    }

    public mutating func down(
        _ sample: TouchSample,
        key: PlacedKey,
        thumb: Thumb,
        shifted: Bool,
        otherThumbDown: Bool
    ) -> [Observation] {
        guard let index = freeSlot() else { return [] }
        var slot = Slot()
        slot.occupied = true
        slot.finger = sample.finger
        slot.thumb = thumb
        slot.extra = strokingThumbCount(excluding: index) >= 2 || sameThumbAlreadyStroking(thumb, excluding: index)
        slot.origin = sample.point
        slot.last = sample.point
        slot.landing = key
        slot.currentID = key.id
        slot.downTime = sample.time.milliseconds
        slot.lastKeyTime = sample.time.milliseconds
        slot.shifted = shifted
        slot.otherThumbDown = otherThumbDown
        if key.kind.isStrokeEligible, let letter = key.letter, let byte = LetterByte.byte(letter) {
            slot.observations[0] = makeObservation(
                byte: byte,
                key: key,
                at: sample.time.milliseconds,
                point: sample.point,
                slot: slot,
                kind: .tap,
                stroke: 0
            )
            slot.observationCount = 1
            slot.lastKeyCenter = key.frame.center
        } else {
            slot.nonLetter = key.kind
        }
        slot.pointCount = 1
        slot.points[0] = sample.point
        slots[index] = slot
        activeCount += 1
        return []
    }

    public mutating func move(_ sample: TouchSample, key: PlacedKey?, otherThumbDown: Bool) -> [Observation] {
        guard let index = index(of: sample.finger) else { return [] }
        var slot = slots[index]
        slot.otherThumbDown = otherThumbDown
        appendPoint(sample.point, to: &slot)
        guard slot.nonLetter == nil else {
            slot.last = sample.point
            slots[index] = slot
            return []
        }
        if slot.extra {
            slot.last = sample.point
            slots[index] = slot
            return []
        }
        var published: [Observation] = []
        if !slot.isStroke, crossedThreshold(sample.point, slot: slot) {
            slot.isStroke = true
            slot.strokeID = strokeSerial
            strokeSerial &+= 1
            if strokeSerial == 0 { strokeSerial = 1 }
            if slot.observationCount > 0 {
                let held = sample.time.milliseconds - slot.downTime
                slot.observations[0].kind = held >= GestureThresholds.pinMilliseconds ? .pin : .anchor
                slot.observations[0].stroke = slot.strokeID
                slot.observations[0].otherThumbDown = otherThumbDown
                if slot.published == 0 {
                    published.append(slot.observations[0])
                    slot.published = 1
                }
            }
        }
        if slot.isStroke, let key, key.kind.isStrokeEligible, key.id != slot.currentID,
           let letter = key.letter, let byte = LetterByte.byte(letter) {
            let kind = cornerKind(from: slot, to: key)
            var observation = makeObservation(
                byte: byte,
                key: key,
                at: sample.time.milliseconds,
                point: sample.point,
                slot: slot,
                kind: kind,
                stroke: slot.strokeID
            )
            observation.otherThumbDown = otherThumbDown
            if slot.observationCount < 32 {
                slot.observations[slot.observationCount] = observation
                slot.observationCount += 1
                published.append(observation)
                slot.published = slot.observationCount
            }
            slot.currentID = key.id
            slot.lastKeyTime = sample.time.milliseconds
            slot.previousVector = Point(x: key.frame.center.x - slot.lastKeyCenter.x, y: key.frame.center.y - slot.lastKeyCenter.y)
            slot.lastKeyCenter = key.frame.center
        } else if slot.isStroke {
            upgradeDwell(&slot, time: sample.time.milliseconds, otherThumbDown: otherThumbDown)
        }
        slot.last = sample.point
        slots[index] = slot
        return published
    }

    public mutating func up(_ sample: TouchSample, otherThumbDown: Bool) -> [Observation] {
        end(sample, cancelled: false, otherThumbDown: otherThumbDown)
    }

    public mutating func cancel(_ sample: TouchSample, otherThumbDown: Bool) -> [Observation] {
        end(sample, cancelled: true, otherThumbDown: otherThumbDown)
    }

    public func spaceTravel(for finger: FingerID, at time: Int) -> (distance: Double, dx: Double, dy: Double, held: Int)? {
        guard let index = index(of: finger), slots[index].nonLetter == .space else { return nil }
        let slot = slots[index]
        let dx = slot.last.x - slot.origin.x
        let dy = slot.last.y - slot.origin.y
        return ((dx * dx + dy * dy).squareRoot(), dx, dy, time - slot.downTime)
    }

    private mutating func end(_ sample: TouchSample, cancelled: Bool, otherThumbDown: Bool) -> [Observation] {
        guard let index = index(of: sample.finger) else { return [] }
        var slot = slots[index]
        var published: [Observation] = []
        if cancelled, !slot.isStroke {
            clear(index)
            return []
        }
        if slot.nonLetter == nil, slot.observationCount > 0 {
            if !slot.isStroke {
                let held = sample.time.milliseconds - slot.downTime
                if held >= GestureThresholds.restMilliseconds, otherThumbDown {
                    slot.observations[0].kind = .rest
                } else if held >= GestureThresholds.pinMilliseconds {
                    slot.observations[0].kind = .pin
                } else {
                    slot.observations[0].kind = .tap
                }
                slot.observations[0].time = slot.downTime
                slot.observations[0].otherThumbDown = otherThumbDown
                published.append(slot.observations[0])
            } else {
                let last = slot.observationCount - 1
                if slot.observations[last].kind == .crossing {
                    slot.observations[last].kind = .anchor
                }
                upgradeDwell(&slot, time: sample.time.milliseconds, otherThumbDown: otherThumbDown)
                if slot.published < slot.observationCount {
                    for cursor in slot.published..<slot.observationCount {
                        published.append(slot.observations[cursor])
                    }
                } else if slot.observations[last].kind == .anchor {
                    published.append(slot.observations[last])
                }
            }
        }
        clear(index)
        return published
    }

    private mutating func clear(_ index: Int) {
        slots[index] = Slot()
        activeCount = max(0, activeCount - 1)
    }

    private func freeSlot() -> Int? {
        for index in 0..<5 where !slots[index].occupied { return index }
        return nil
    }

    private func index(of finger: FingerID) -> Int? {
        for index in 0..<5 where slots[index].occupied && slots[index].finger == finger { return index }
        return nil
    }

    private func strokingThumbCount(excluding index: Int) -> Int {
        var count = 0
        var seen: Set<Thumb> = []
        for cursor in 0..<5 where cursor != index && slots[cursor].occupied && !slots[cursor].extra {
            if seen.insert(slots[cursor].thumb).inserted { count += 1 }
        }
        return count
    }

    private func sameThumbAlreadyStroking(_ thumb: Thumb, excluding index: Int) -> Bool {
        for cursor in 0..<5 where cursor != index && slots[cursor].occupied && slots[cursor].thumb == thumb && !slots[cursor].extra {
            return true
        }
        return false
    }

    private func crossedThreshold(_ point: Point, slot: Slot) -> Bool {
        let dx = abs(point.x - slot.origin.x)
        let distance = slot.origin.distance(to: point)
        if dx >= GestureThresholds.sideways || distance >= GestureThresholds.anyDirection {
            return true
        }
        if let landing = slot.landing, landing.frame.distanceOutside(point) >= GestureThresholds.beyondKey {
            return true
        }
        return false
    }

    private func cornerKind(from slot: Slot, to key: PlacedKey) -> ObservationKind {
        let vector = Point(x: key.frame.center.x - slot.lastKeyCenter.x, y: key.frame.center.y - slot.lastKeyCenter.y)
        let previous = slot.previousVector
        let previousLength = (previous.x * previous.x + previous.y * previous.y).squareRoot()
        let length = (vector.x * vector.x + vector.y * vector.y).squareRoot()
        if previousLength > 1, length > 1 {
            let dot = (previous.x * vector.x + previous.y * vector.y) / (previousLength * length)
            if dot < GestureThresholds.cornerDotLimit { return .anchor }
        }
        return .crossing
    }

    private func upgradeDwell(_ slot: inout Slot, time: Int, otherThumbDown: Bool) {
        guard slot.observationCount > 0 else { return }
        let last = slot.observationCount - 1
        let held = time - slot.lastKeyTime
        if held >= GestureThresholds.restMilliseconds, otherThumbDown {
            slot.observations[last].kind = .rest
        } else if held >= GestureThresholds.pinMilliseconds, slot.observations[last].kind != .anchor {
            slot.observations[last].kind = .pin
        }
    }

    private func appendPoint(_ point: Point, to slot: inout Slot) {
        if slot.pointCount < 64 {
            slot.points[slot.pointCount] = point
            slot.pointCount += 1
        } else {
            slot.points[63] = point
        }
    }

    private func makeObservation(
        byte: UInt8,
        key: PlacedKey,
        at time: Int,
        point: Point,
        slot: Slot,
        kind: ObservationKind,
        stroke: UInt8
    ) -> Observation {
        let center = key.frame.center
        let centered = abs(point.x - center.x) < key.frame.size.width * 0.35
            && abs(point.y - center.y) < key.frame.size.height * 0.35
        return Observation(
            letter: byte,
            shifted: slot.shifted,
            kind: kind,
            thumb: slot.thumb,
            time: time,
            x: point.x,
            y: point.y,
            keyX: center.x,
            keyY: center.y,
            keyWidth: key.frame.size.width,
            keyHeight: key.frame.size.height,
            centered: centered,
            stroke: stroke,
            otherThumbDown: slot.otherThumbDown
        )
    }

    private struct Slot: Sendable {
        var occupied = false
        var finger = FingerID(0)
        var thumb = Thumb.left
        var extra = false
        var origin = Point.zero
        var last = Point.zero
        var landing: PlacedKey?
        var currentID = ""
        var lastKeyCenter = Point.zero
        var previousVector = Point.zero
        var isStroke = false
        var strokeID: UInt8 = 0
        var downTime = 0
        var lastKeyTime = 0
        var shifted = false
        var otherThumbDown = false
        var nonLetter: KeyKind?
        var pointCount = 0
        var points = InlineArray<64, Point>(repeating: .zero)
        var observationCount = 0
        var published = 0
        var observations = InlineArray<32, Observation>(repeating: .placeholder)
    }
}
