public enum ChipRole: Sendable, Equatable {
    case leader
    case alternative
    case aimed
    case suffix
    case follower
    case context
}

public struct Chip: Sendable, Equatable, Identifiable {
    public var text: String
    public var role: ChipRole
    public var id: String { text.lowercased() }

    public init(text: String, role: ChipRole) {
        self.text = text
        self.role = role
    }
}

public struct Strip: Sendable, Equatable {
    public var chips: [Chip]
    public var highlighted: Int?
    public var preview: Bool

    public init(chips: [Chip] = [], highlighted: Int? = nil, preview: Bool = false) {
        self.chips = chips
        self.highlighted = highlighted
        self.preview = preview
    }

    public static let empty = Strip()
}
