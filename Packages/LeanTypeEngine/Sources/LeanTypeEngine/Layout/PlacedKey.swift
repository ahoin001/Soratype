public struct PlacedKey: Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var kind: KeyKind
    public var label: String
    public var frame: Rect

    public init(id: String, kind: KeyKind, label: String, frame: Rect) {
        self.id = id
        self.kind = kind
        self.label = label
        self.frame = frame
    }

    public var letter: Character? {
        if case .letter(let character) = kind { return character }
        return nil
    }
}
