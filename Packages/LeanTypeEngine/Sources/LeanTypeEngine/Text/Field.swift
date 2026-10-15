public struct Field: Sendable, Equatable {
    public private(set) var text: String
    public private(set) var caret: Int
    public private(set) var marked: Range<Int>?

    public init(text: String = "", caret: Int = 0, marked: Range<Int>? = nil) {
        self.text = text
        self.caret = min(max(0, caret), text.count)
        self.marked = marked
    }

    public var display: String { text }

    public var composing: String {
        guard let marked, marked.upperBound <= text.count else { return "" }
        return String(text.dropFirst(marked.lowerBound).prefix(marked.count))
    }

    public mutating func setComposing(_ word: String) {
        let prefix: String
        let suffix: String
        if let marked, marked.upperBound <= text.count {
            prefix = String(text.prefix(marked.lowerBound))
            suffix = String(text.dropFirst(marked.upperBound))
        } else {
            let safe = min(caret, text.count)
            prefix = String(text.prefix(safe))
            suffix = String(text.dropFirst(safe))
        }
        text = prefix + word + suffix
        let start = prefix.count
        marked = word.isEmpty ? nil : start..<(start + word.count)
        caret = start + word.count
    }

    public mutating func commitComposing(_ word: String) {
        setComposing(word)
        marked = nil
    }

    public mutating func insert(_ insertion: String) {
        let safe = min(caret, text.count)
        let prefix = String(text.prefix(safe))
        let suffix = String(text.dropFirst(safe))
        text = prefix + insertion + suffix
        caret = prefix.count + insertion.count
        marked = nil
    }

    public mutating func deleteBackward(_ count: Int) {
        guard count > 0, caret > 0 else { return }
        let safe = min(caret, text.count)
        let start = max(0, safe - count)
        let prefix = String(text.prefix(start))
        let suffix = String(text.dropFirst(safe))
        text = prefix + suffix
        caret = prefix.count
        marked = nil
    }

    public mutating func replace(from start: Int, through end: Int, with replacement: String) {
        let lower = min(max(0, start), text.count)
        let upper = min(max(lower, end), text.count)
        let prefix = String(text.prefix(lower))
        let suffix = String(text.dropFirst(upper))
        text = prefix + replacement + suffix
        caret = prefix.count + replacement.count
        marked = nil
    }

    public mutating func moveCaret(to offset: Int) {
        caret = min(max(0, offset), text.count)
        if let marked, !marked.contains(caret) && caret != marked.upperBound {
            marked = nil
        }
    }
}
