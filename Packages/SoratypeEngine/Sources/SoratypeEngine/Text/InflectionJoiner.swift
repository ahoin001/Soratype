public enum InflectionJoiner {
    public static let suffixes = ["ing", "ed", "es", "ly", "er", "est", "s"]

    public static func suffix(in draft: String) -> String? {
        let letters = draft.lowercased()
        return suffixes.first { $0 == letters }
    }

    public static func joined(stem: String, suffix: String, lexicon: any Lexicon) -> String? {
        let word = stem.lowercased() + suffix.lowercased()
        guard suffixes.contains(suffix.lowercased()), lexicon.contains(word) else { return nil }
        return word
    }
}
