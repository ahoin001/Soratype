public enum EngineEffect: Sendable, Equatable {
    case setMarked(String)
    case commit(String)
    case insert(String)
    case deleteBackward(Int)
    case replaceTail(delete: Int, insert: String)
    case strip(Strip)
    case page(KeyboardPage)
}
