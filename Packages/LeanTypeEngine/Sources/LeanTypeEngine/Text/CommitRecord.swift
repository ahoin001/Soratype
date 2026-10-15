struct CommitRecord: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case swipe
        case tap
        case autocorrect
        case suffix
        case strip
        case period
    }

    var kind: Kind
    var word: String
    var aimed: String
    var typed: String
    var trailingSpace: Bool
    var alternatives: [String]
    var stem: String?
    var suffix: String?
    var caret: Int
    var observations: [Observation]
}

enum RepeatUnit: Sendable, Equatable {
    case character
    case word
}

enum PendingPurpose: Sendable {
    case preview
    case lift(Int)
    case settle(SettleReason)
}
