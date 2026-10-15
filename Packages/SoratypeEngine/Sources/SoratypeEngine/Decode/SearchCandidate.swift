struct SearchCandidate: Sendable, Equatable {
    var bytes: [UInt8]
    var shifts: UInt64
    var score: Double

    var lowercase: String { LetterByte.spelling(bytes) }
    var display: String { LetterByte.spelling(bytes, shifts: shifts) }
}
