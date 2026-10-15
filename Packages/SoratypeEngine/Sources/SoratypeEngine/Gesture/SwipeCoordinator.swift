/// One chain per thumb. A third contact is never a chain.
public struct SwipeCoordinator: Sendable {
    public init() {}

    public func activeThumbs(in observations: [Observation]) -> Set<Thumb> {
        Set(observations.map(\.thumb))
    }

    public func chainsOverlap(_ observations: [Observation]) -> Bool {
        let left = observations.filter { $0.thumb == .left }
        let right = observations.filter { $0.thumb == .right }
        guard let leftFirst = left.first?.time, let leftLast = left.last?.time,
              let rightFirst = right.first?.time, let rightLast = right.last?.time
        else { return false }
        return leftFirst <= rightLast && rightFirst <= leftLast
    }
}
