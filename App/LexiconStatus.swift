struct LexiconStatus: Equatable {
    var wordCount: Int
    var byteCount: Int
    var note: String

    static let missing = LexiconStatus(
        wordCount: 0,
        byteCount: 0,
        note: "The English word list has not been installed yet."
    )
}
