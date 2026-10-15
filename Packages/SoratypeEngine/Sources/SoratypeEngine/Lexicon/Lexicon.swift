public struct LexiconNode: Sendable, Hashable, Equatable {
    public var index: Int

    public init(index: Int) {
        self.index = index
    }
}

public protocol Lexicon: Sendable {
    var wordCount: Int { get }
    var root: LexiconNode { get }
    func child(_ node: LexiconNode, _ byte: UInt8) -> LexiconNode?
    func rank(_ node: LexiconNode) -> UInt16
    func endpoints(first: UInt8, last: UInt8) -> [String]
    func isOffensive(_ word: String) -> Bool
    func followers(of word: String) -> [String]
}

extension Lexicon {
    public func contains(_ word: String) -> Bool {
        rank(of: word) != nil
    }

    public func rank(of word: String) -> UInt16? {
        var node = root
        for byte in word.lowercased().utf8 {
            guard let next = child(node, byte) else { return nil }
            node = next
        }
        let value = rank(node)
        return value == 0 ? nil : value
    }

    public func isOffensive(_ word: String) -> Bool { false }

    public func followers(of word: String) -> [String] { [] }

    public func isPrefix(_ word: String) -> Bool {
        var node = root
        for byte in word.lowercased().utf8 {
            guard let next = child(node, byte) else { return false }
            node = next
        }
        return true
    }
}
