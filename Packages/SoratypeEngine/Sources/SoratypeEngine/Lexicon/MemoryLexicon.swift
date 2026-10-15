public struct MemoryLexicon: Lexicon, Sendable {
    private var nodes: [Node]
    private var endpointIndex: [UInt16: [String]]
    private var offensiveWords: Set<String>
    private var followerIndex: [String: [String]]
    public let wordCount: Int
    public let root = LexiconNode(index: 0)

    public init(
        wordsInFrequencyOrder words: [String],
        offensive: Set<String> = [],
        followers: [String: [String]] = [:]
    ) {
        var nodes = [Node()]
        var endpoints: [UInt16: [String]] = [:]
        var count = 0
        var seen = Set<String>()
        let blocked = Set(offensive.map { $0.lowercased() })
        for (offset, raw) in words.enumerated() {
            let word = raw.lowercased()
            guard !word.isEmpty, seen.insert(word).inserted else { continue }
            let bytes = Array(word.utf8)
            guard bytes.allSatisfy({ $0 == 39 || (97...122).contains($0) }) else { continue }
            var index = 0
            for byte in bytes {
                if let existing = nodes[index].children[byte] {
                    index = existing
                } else {
                    let child = nodes.count
                    nodes.append(Node())
                    nodes[index].children[byte] = child
                    index = child
                }
            }
            let rank = UInt16(min(offset + 1, Int(UInt16.max)))
            if nodes[index].rank == 0 {
                nodes[index].rank = rank
                count += 1
                if let first = bytes.first, let last = bytes.last {
                    let key = UInt16(first) << 8 | UInt16(last)
                    var bucket = endpoints[key] ?? []
                    if bucket.count < 180 {
                        bucket.append(word)
                        endpoints[key] = bucket
                    }
                }
            }
        }
        var followerIndex: [String: [String]] = [:]
        for (head, next) in followers {
            let key = head.lowercased()
            guard seen.contains(key) else { continue }
            let kept = next.map { $0.lowercased() }.filter { seen.contains($0) }
            if !kept.isEmpty { followerIndex[key] = kept }
        }
        self.nodes = nodes
        self.endpointIndex = endpoints
        self.offensiveWords = blocked.intersection(seen)
        self.followerIndex = followerIndex
        self.wordCount = count
    }

    public func child(_ node: LexiconNode, _ byte: UInt8) -> LexiconNode? {
        guard nodes.indices.contains(node.index), let next = nodes[node.index].children[byte] else { return nil }
        return LexiconNode(index: next)
    }

    public func rank(_ node: LexiconNode) -> UInt16 {
        guard nodes.indices.contains(node.index) else { return 0 }
        return nodes[node.index].rank
    }

    public func endpoints(first: UInt8, last: UInt8) -> [String] {
        endpointIndex[UInt16(first) << 8 | UInt16(last)] ?? []
    }

    public func isOffensive(_ word: String) -> Bool {
        offensiveWords.contains(word.lowercased())
    }

    public func followers(of word: String) -> [String] {
        followerIndex[word.lowercased()] ?? []
    }

    private struct Node: Sendable {
        var children: [UInt8: Int] = [:]
        var rank: UInt16 = 0
    }
}
