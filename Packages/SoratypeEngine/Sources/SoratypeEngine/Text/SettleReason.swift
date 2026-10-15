public enum SettleReason: Sendable, Equatable {
    case space
    case `return`
    case punctuation
    case emoji
    case caret
    case focusLoss
    case dismissal
    case liftWord
}
