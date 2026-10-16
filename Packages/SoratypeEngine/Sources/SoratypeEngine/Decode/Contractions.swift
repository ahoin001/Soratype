/// Curated contractions. The key is the letters with the apostrophe removed.
enum Contractions {
    private static let forms = [
        "don't", "I'm", "it's", "you're", "we're", "they're", "that's", "what's", "there's",
        "he's", "she's", "isn't", "aren't", "wasn't", "weren't", "can't", "won't", "wouldn't",
        "shouldn't", "couldn't", "didn't", "doesn't", "haven't", "hasn't", "hadn't", "let's",
        "I've", "you've", "we've", "they've", "I'll", "you'll", "we'll", "they'll",
    ]

    private static let byBare: [String: String] = {
        var map: [String: String] = [:]
        for form in forms {
            map[bare(form)] = form
        }
        return map
    }()

    static func display(matching aimed: String) -> String? {
        byBare[bare(aimed)]
    }

    static func bare(_ spelling: String) -> String {
        spelling.lowercased().filter { $0 != "'" }
    }
}
