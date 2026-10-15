public enum EngineInput: Sendable, Equatable {
    case touch(TouchSample)
    case boundary(Boundary)
    case tick(EngineInstant)
    case host(HostEvent)
    case promoteChip(Int)
    case acceptChip(Int)
    case rejectChip(Int)
    case suppressLiftDelete
}
