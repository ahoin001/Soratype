public enum HostEvent: Sendable, Equatable {
    case dismiss
    case focusLoss
    case textChanged(String, caret: Int)
    case verbatim(Bool)
}
