public enum KeyKind: Sendable, Equatable, Hashable {
    case letter(Character)
    case digit(Character)
    case punctuation(Character)
    case space
    case backspace
    case `return`
    case shift
    case symbols
    case letters

    public var isStrokeEligible: Bool {
        if case .letter = self { return true }
        return false
    }

    public var insertedText: String? {
        switch self {
        case .letter(let character), .digit(let character), .punctuation(let character):
            String(character)
        case .space:
            " "
        case .return:
            "\n"
        case .backspace, .shift, .symbols, .letters:
            nil
        }
    }
}
