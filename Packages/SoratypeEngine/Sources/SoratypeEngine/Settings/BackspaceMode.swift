public enum BackspaceMode: String, Sendable, Equatable, Codable {
    /// Remove a finished swipe and its trailing space. Aimed letters stay on the strip.
    case removeWordAndSpace
    /// Put the aimed letters back into composing text.
    case reopenAimedLetters
}
