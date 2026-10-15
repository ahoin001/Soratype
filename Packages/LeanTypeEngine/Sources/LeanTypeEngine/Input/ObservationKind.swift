public enum ObservationKind: UInt8, Sendable, Equatable, Hashable {
    case anchor
    case crossing
    case tap
    case pin
    case rest
    case slip
}
