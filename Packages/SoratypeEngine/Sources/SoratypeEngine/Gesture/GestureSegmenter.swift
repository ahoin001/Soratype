/// Decides whether travel is a tap, a hold, or a stroke. Reuses fixed buffers.
public struct GestureSegmenter: Sendable {
    private var slots: InlineArray<5, Slot>
    private var traces: InlineArray<5, Trace>
    private var strokeSerial: UInt8 = 1
    public private(set) var activeCount = 0

    public init() {
        slots = InlineArray(repeating: Slot())
        traces = InlineArray(repeating: Trace())
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
        let extra = strokingThumbCount(excluding: index) >= 2 || sameThumbAlreadyStroking(thumb, excluding: index)
        placeEmpty(at: index)
        Self.open(
            &slots[index],
            trace: &traces[index],
            sample: sample,
            key: key,
            thumb: thumb,
            shifted: shifted,
            otherThumbDown: otherThumbDown,
            extra: extra
        )
        activeCount += 1
        guard traces[index].observationCount > 0 else { return [] }
        traces[index].published = 1
        noteTypedAround(excludingFinger: sample.finger)
        return [traces[index].observations[0]]
    }

    public mutating func move(_ sample: TouchSample, key: PlacedKey?, otherThumbDown: Bool) -> [Observation] {
        guard let index = index(of: sample.finger) else { return [] }
        let nextStrokeID = strokeSerial
        var startedStroke = false
        let published = Self.follow(
            &slots[index],
            trace: &traces[index],
            sample: sample,
            key: key,
            otherThumbDown: otherThumbDown,
            nextStrokeID: nextStrokeID,
            startedStroke: &startedStroke
        )
        if startedStroke {
            strokeSerial &+= 1
            if strokeSerial == 0 { strokeSerial = 1 }
        }
        if !published.isEmpty {
            noteTypedAround(excludingFinger: sample.finger)
        }
        return published
    }

    public mutating func up(_ sample: TouchSample, otherThumbDown: Bool) -> [Observation] {
        end(sample, cancelled: false, otherThumbDown: otherThumbDown)
    }

    public mutating func cancel(_ sample: TouchSample, otherThumbDown: Bool) -> [Observation] {
        end(sample, cancelled: true, otherThumbDown: otherThumbDown)
    }

    public func landingKey(for finger: FingerID) -> PlacedKey? {
        guard let index = index(of: finger) else { return nil }
        return slots[index].landing
    }

    public func spaceTravel(for finger: FingerID, at time: Int) -> (distance: Double, dx: Double, dy: Double, held: Int)? {
        guard let index = index(of: finger), slots[index].nonLetter == .space else { return nil }
        let dx = slots[index].last.x - slots[index].origin.x
        let dy = slots[index].last.y - slots[index].origin.y
        let held = time - slots[index].downTime
        return ((dx * dx + dy * dy).squareRoot(), dx, dy, held)
    }

    private mutating func end(_ sample: TouchSample, cancelled: Bool, otherThumbDown: Bool) -> [Observation] {
        guard let index = index(of: sample.finger) else { return [] }
        let published = Self.lift(
            &slots[index],
            trace: &traces[index],
            sample: sample,
            cancelled: cancelled,
            otherThumbDown: otherThumbDown
        )
        if !published.isEmpty {
            noteTypedAround(excludingFinger: slots[index].finger)
        }
        clear(index)
        return published
    }

    private mutating func placeEmpty(at index: Int) {
        slots[index] = Slot()
        traces[index] = Trace()
    }

    private static func open(
        _ slot: inout Slot,
        trace: inout Trace,
        sample: TouchSample,
        key: PlacedKey,
        thumb: Thumb,
        shifted: Bool,
        otherThumbDown: Bool,
        extra: Bool
    ) {
        slot.occupied = true
        slot.finger = sample.finger
        slot.thumb = thumb
        slot.extra = extra
        slot.origin = sample.point
        slot.last = sample.point
        slot.landing = key
        slot.currentID = key.id
        slot.downTime = sample.time.milliseconds
        slot.lastKeyTime = sample.time.milliseconds
        slot.shifted = shifted
        slot.otherThumbDown = otherThumbDown
        if key.kind.isStrokeEligible, let letter = key.letter, let byte = LetterByte.byte(letter) {
            trace.observations[0] = makeObservation(
                byte: byte,
                key: key,
                at: sample.time.milliseconds,
                point: sample.point,
                thumb: thumb,
                shifted: shifted,
                otherThumbDown: otherThumbDown,
                kind: .tap,
                stroke: 0
            )
            trace.observationCount = 1
            slot.lastKeyCenter = key.frame.center
            beginVisit(key, at: sample.time.milliseconds, point: sample.point, slot: &slot)
        } else {
            slot.nonLetter = key.kind
        }
        trace.pointCount = 1
        trace.points[0] = sample.point
    }

    private static func follow(
        _ slot: inout Slot,
        trace: inout Trace,
        sample: TouchSample,
        key: PlacedKey?,
        otherThumbDown: Bool,
        nextStrokeID: UInt8,
        startedStroke: inout Bool
    ) -> [Observation] {
        slot.otherThumbDown = otherThumbDown
        appendPoint(sample.point, to: &trace)
        if slot.nonLetter != nil || slot.extra {
            slot.last = sample.point
            return []
        }
        var published: [Observation] = []
        if !slot.isStroke {
            startedStroke = considerStroke(
                &slot,
                trace: &trace,
                sample: sample,
                otherThumbDown: otherThumbDown,
                nextStrokeID: nextStrokeID,
                published: &published
            )
        }
        if slot.isStroke {
            trackVisit(&slot, trace: &trace, sample: sample, key: key, otherThumbDown: otherThumbDown, published: &published)
        }
        slot.last = sample.point
        return published
    }

    private static func lift(
        _ slot: inout Slot,
        trace: inout Trace,
        sample: TouchSample,
        cancelled: Bool,
        otherThumbDown: Bool
    ) -> [Observation] {
        if cancelled, !slot.isStroke {
            guard trace.published > 0, trace.observationCount > 0 else { return [] }
            return [trace.observations[0]]
        }
        guard slot.nonLetter == nil, trace.observationCount > 0 else { return [] }
        if !slot.isStroke {
            return [liftedTap(&slot, trace: &trace, at: sample.time.milliseconds, otherThumbDown: otherThumbDown)]
        }
        var published: [Observation] = []
        finishStroke(
            &slot,
            trace: &trace,
            at: sample.point,
            time: sample.time.milliseconds,
            otherThumbDown: otherThumbDown,
            published: &published
        )
        return published
    }

    private static func liftedTap(
        _ slot: inout Slot,
        trace: inout Trace,
        at time: Int,
        otherThumbDown: Bool
    ) -> Observation {
        let held = time - slot.downTime
        if held >= GestureThresholds.restMilliseconds, otherThumbDown {
            trace.observations[0].kind = .rest
        } else if held >= GestureThresholds.pinMilliseconds {
            trace.observations[0].kind = .pin
        } else {
            trace.observations[0].kind = .tap
        }
        trace.observations[0].time = slot.downTime
        trace.observations[0].otherThumbDown = otherThumbDown
        trace.observations[0].lifted = true
        trace.observations[0].liftTime = time
        return trace.observations[0]
    }

    private static func finishStroke(
        _ slot: inout Slot,
        trace: inout Trace,
        at point: Point,
        time: Int,
        otherThumbDown: Bool,
        published: inout [Observation]
    ) {
        if !slot.visitStamped {
            stampLift(&slot, trace: &trace, at: point, otherThumbDown: otherThumbDown)
        }
        upgradeDwell(&slot, trace: &trace, time: time, otherThumbDown: otherThumbDown)
        guard trace.observationCount > 0 else { return }
        let lastIndex = trace.observationCount - 1
        if slot.visitStamped, trace.observations[lastIndex].kind == .crossing {
            trace.observations[lastIndex].kind = .anchor
        }
        if trace.published < trace.observationCount {
            for cursor in trace.published..<trace.observationCount {
                published.append(trace.observations[cursor])
            }
        } else {
            let last = trace.observations[lastIndex]
            switch last.kind {
            case .anchor, .pin, .rest:
                published.append(last)
            case .tap, .crossing, .slip:
                break
            }
        }
    }

    private mutating func clear(_ index: Int) {
        slots[index] = Slot()
        traces[index] = Trace()
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

    /// A second contact on a thumb that is already drawing. A planted finger has not chosen a stroke yet.
    private func sameThumbAlreadyStroking(_ thumb: Thumb, excluding index: Int) -> Bool {
        for cursor in 0..<5 where cursor != index
            && slots[cursor].occupied
            && slots[cursor].isStroke
            && slots[cursor].thumb == thumb
            && !slots[cursor].extra {
            return true
        }
        return false
    }

    /// Another finger published a letter while this one was still planted.
    /// Same-side keys still count: thumb identity follows the key, not the hand.
    private mutating func noteTypedAround(excludingFinger finger: FingerID) {
        for index in 0..<5 where slots[index].occupied
            && slots[index].finger != finger
            && !slots[index].isStroke
            && !slots[index].extra {
            slots[index].overlapped = true
        }
    }

    private static func considerStroke(
        _ slot: inout Slot,
        trace: inout Trace,
        sample: TouchSample,
        otherThumbDown: Bool,
        nextStrokeID: UInt8,
        published: inout [Observation]
    ) -> Bool {
        guard crossedThreshold(sample.point, origin: slot.origin, landing: slot.landing) else { return false }
        slot.isStroke = true
        slot.strokeID = nextStrokeID
        guard trace.observationCount > 0 else { return true }
        let held = sample.time.milliseconds - slot.downTime
        let pinned = slot.overlapped || held >= GestureThresholds.pinMilliseconds
        trace.observations[0].kind = pinned ? .pin : .anchor
        trace.observations[0].stroke = nextStrokeID
        trace.observations[0].otherThumbDown = otherThumbDown
        published.append(trace.observations[0])
        if trace.published == 0 {
            trace.published = 1
        }
        slot.visitStamped = true
        return true
    }

    private static func trackVisit(
        _ slot: inout Slot,
        trace: inout Trace,
        sample: TouchSample,
        key: PlacedKey?,
        otherThumbDown: Bool,
        published: inout [Observation]
    ) {
        guard let key, key.kind.isStrokeEligible else {
            upgradeDwell(&slot, trace: &trace, time: sample.time.milliseconds, otherThumbDown: otherThumbDown)
            return
        }
        if key.id != slot.currentID {
            flushGraze(&slot, trace: &trace, otherThumbDown: otherThumbDown, into: &published)
            beginVisit(key, at: sample.time.milliseconds, point: sample.point, slot: &slot)
        }
        guard !slot.visitStamped else {
            upgradeDwell(&slot, trace: &trace, time: sample.time.milliseconds, otherThumbDown: otherThumbDown)
            return
        }
        guard isNearCenter(sample.point, key: key) else { return }
        stampArrival(&slot, trace: &trace, sample: sample, key: key, otherThumbDown: otherThumbDown, published: &published)
    }

    private static func stampArrival(
        _ slot: inout Slot,
        trace: inout Trace,
        sample: TouchSample,
        key: PlacedKey,
        otherThumbDown: Bool,
        published: inout [Observation]
    ) {
        guard let letter = key.letter, let byte = LetterByte.byte(letter) else { return }
        let kind = cornerKind(from: slot.lastKeyCenter, previous: slot.previousVector, to: key)
        var observation = makeObservation(
            byte: byte,
            key: key,
            at: sample.time.milliseconds,
            point: sample.point,
            thumb: slot.thumb,
            shifted: slot.shifted,
            otherThumbDown: otherThumbDown,
            kind: kind,
            stroke: slot.strokeID
        )
        observation.otherThumbDown = otherThumbDown
        append(observation, to: &slot, trace: &trace, published: &published)
        noteStamp(of: key, on: &slot, at: sample.time.milliseconds)
    }

    private static func crossedThreshold(_ point: Point, origin: Point, landing: PlacedKey?) -> Bool {
        let dx = abs(point.x - origin.x)
        let distance = origin.distance(to: point)
        if dx >= GestureThresholds.sideways || distance >= GestureThresholds.anyDirection {
            return true
        }
        if let landing, landing.frame.distanceOutside(point) >= GestureThresholds.beyondKey {
            return true
        }
        return false
    }

    private static func isNearCenter(_ point: Point, key: PlacedKey) -> Bool {
        let center = key.frame.center
        return abs(point.x - center.x) < key.frame.size.width * 0.35
            && abs(point.y - center.y) < key.frame.size.height * 0.35
    }

    private static func beginVisit(_ key: PlacedKey, at time: Int, point: Point, slot: inout Slot) {
        slot.currentID = key.id
        slot.visitKey = key
        slot.visitEntered = time
        slot.visitPoint = point
        slot.visitStamped = false
    }

    private static func noteStamp(of key: PlacedKey, on slot: inout Slot, at time: Int) {
        let center = key.frame.center
        slot.previousVector = Point(x: center.x - slot.lastKeyCenter.x, y: center.y - slot.lastKeyCenter.y)
        slot.lastKeyCenter = center
        slot.lastKeyTime = time
    }

    private static func flushGraze(
        _ slot: inout Slot,
        trace: inout Trace,
        otherThumbDown: Bool,
        into published: inout [Observation]
    ) {
        guard slot.isStroke, !slot.visitStamped, let key = slot.visitKey,
              key.kind.isStrokeEligible, let letter = key.letter, let byte = LetterByte.byte(letter)
        else { return }
        var observation = makeObservation(
            byte: byte,
            key: key,
            at: slot.visitEntered,
            point: slot.visitPoint,
            thumb: slot.thumb,
            shifted: slot.shifted,
            otherThumbDown: otherThumbDown,
            kind: .crossing,
            stroke: slot.strokeID
        )
        observation.otherThumbDown = otherThumbDown
        observation.centered = false
        append(observation, to: &slot, trace: &trace, published: &published)
    }

    private static func stampLift(
        _ slot: inout Slot,
        trace: inout Trace,
        at point: Point,
        otherThumbDown: Bool
    ) {
        guard let key = slot.visitKey, key.kind.isStrokeEligible,
              let letter = key.letter, let byte = LetterByte.byte(letter),
              trace.observationCount < 32
        else { return }
        var observation = makeObservation(
            byte: byte,
            key: key,
            at: slot.visitEntered,
            point: point,
            thumb: slot.thumb,
            shifted: slot.shifted,
            otherThumbDown: otherThumbDown,
            kind: .anchor,
            stroke: slot.strokeID
        )
        observation.otherThumbDown = otherThumbDown
        trace.observations[trace.observationCount] = observation
        trace.observationCount += 1
        slot.visitStamped = true
    }

    private static func append(
        _ observation: Observation,
        to slot: inout Slot,
        trace: inout Trace,
        published: inout [Observation]
    ) {
        guard trace.observationCount < 32 else { return }
        trace.observations[trace.observationCount] = observation
        trace.observationCount += 1
        published.append(observation)
        trace.published = trace.observationCount
        slot.visitStamped = true
    }

    private static func cornerKind(from lastCenter: Point, previous: Point, to key: PlacedKey) -> ObservationKind {
        let vector = Point(x: key.frame.center.x - lastCenter.x, y: key.frame.center.y - lastCenter.y)
        let previousLength = (previous.x * previous.x + previous.y * previous.y).squareRoot()
        let length = (vector.x * vector.x + vector.y * vector.y).squareRoot()
        if previousLength > 1, length > 1 {
            let dot = (previous.x * vector.x + previous.y * vector.y) / (previousLength * length)
            if dot < GestureThresholds.cornerDotLimit { return .anchor }
        }
        return .crossing
    }

    private static func upgradeDwell(
        _ slot: inout Slot,
        trace: inout Trace,
        time: Int,
        otherThumbDown: Bool
    ) {
        guard trace.observationCount > 0 else { return }
        let last = trace.observationCount - 1
        let held = time - slot.lastKeyTime
        let protectsStart = slot.isStroke && last == 0
        if held >= GestureThresholds.restMilliseconds, otherThumbDown, !protectsStart {
            trace.observations[last].kind = .rest
        } else if held >= GestureThresholds.pinMilliseconds, trace.observations[last].kind != .anchor {
            trace.observations[last].kind = .pin
        }
    }

    private static func appendPoint(_ point: Point, to trace: inout Trace) {
        if trace.pointCount < 64 {
            trace.points[trace.pointCount] = point
            trace.pointCount += 1
        } else {
            trace.points[63] = point
        }
    }

    private static func makeObservation(
        byte: UInt8,
        key: PlacedKey,
        at time: Int,
        point: Point,
        thumb: Thumb,
        shifted: Bool,
        otherThumbDown: Bool,
        kind: ObservationKind,
        stroke: UInt8
    ) -> Observation {
        let center = key.frame.center
        let centered = abs(point.x - center.x) < key.frame.size.width * 0.35
            && abs(point.y - center.y) < key.frame.size.height * 0.35
        return Observation(
            letter: byte,
            shifted: shifted,
            kind: kind,
            thumb: thumb,
            time: time,
            x: point.x,
            y: point.y,
            keyX: center.x,
            keyY: center.y,
            keyWidth: key.frame.size.width,
            keyHeight: key.frame.size.height,
            centered: centered,
            stroke: stroke,
            otherThumbDown: otherThumbDown
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
        var overlapped = false
        var nonLetter: KeyKind?
        var visitKey: PlacedKey?
        var visitEntered = 0
        var visitPoint = Point.zero
        var visitStamped = false
    }

    /// Samples and letters for one finger. Kept off `Slot` so a lookup does not copy them.
    private struct Trace: Sendable {
        var pointCount = 0
        var points = InlineArray<64, Point>(repeating: .zero)
        var observationCount = 0
        var published = 0
        var observations = InlineArray<32, Observation>(repeating: .placeholder)
    }
}
