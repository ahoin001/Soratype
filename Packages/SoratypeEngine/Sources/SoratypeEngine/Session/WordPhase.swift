public enum WordPhase: Sendable, Equatable {
    case idle
    case contact
    case tapOpen
    case swipeOpen
    case grace(deadline: Int)
}
