public enum Boundary: Sendable, Equatable {
    case space
    case backspace
    case `return`
    case punctuation(Character)
    case emoji(String)
    case caret(Int)
    case liftWord
}
