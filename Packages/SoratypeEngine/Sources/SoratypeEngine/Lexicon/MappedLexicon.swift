import Foundation

/// One shared mapping of the word list. The keyboard and the decoder both hold this object, so it stays a class.
public final class MappedLexicon: Lexicon, Sendable {
    public let wordCount: Int
    public let root = LexiconNode(index: 0)
    private let data: Data
    private let header: LexiconFormat.Header
    private let followerIndex: [String: [String]]

    public init(data: Data) throws {
        guard let header = LexiconFormat.header(in: data) else {
            throw LexiconError.badMagic
        }
        let nodesEnd = header.nodesOffset + header.nodeCount * LexiconFormat.nodeBytes
        guard data.count >= nodesEnd, data.count >= header.followersOffset else { throw LexiconError.truncated }
        self.data = data
        self.header = header
        self.wordCount = header.wordCount
        self.followerIndex = try Self.readFollowers(data: data, header: header)
    }

    public convenience init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        try self.init(data: data)
    }

    public func child(_ node: LexiconNode, _ byte: UInt8) -> LexiconNode? {
        guard node.index < header.nodeCount else { return nil }
        let record = readNode(node.index)
        guard record.childCount > 0 else { return nil }
        var low = 0
        var high = Int(record.childCount)
        while low < high {
            let mid = (low + high) / 2
            let childIndex = Int(record.childStart) + mid
            guard childIndex < header.nodeCount else { return nil }
            let child = readNode(childIndex)
            if child.character == byte { return LexiconNode(index: childIndex) }
            if child.character < byte {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return nil
    }

    public func rank(_ node: LexiconNode) -> UInt16 {
        guard node.index < header.nodeCount else { return 0 }
        let record = readNode(node.index)
        return record.flags & LexiconFormat.wordFlag == LexiconFormat.wordFlag ? record.rank : 0
    }

    public func isOffensive(_ word: String) -> Bool {
        var node = root
        for byte in word.lowercased().utf8 {
            guard let next = child(node, byte) else { return false }
            node = next
        }
        guard node.index < header.nodeCount else { return false }
        return readNode(node.index).flags & LexiconFormat.offensiveFlag != 0
    }

    public func followers(of word: String) -> [String] {
        followerIndex[word.lowercased()] ?? []
    }

    public func endpoints(first: UInt8, last: UInt8) -> [String] {
        var found: [String] = []
        let base = header.endpointOffset
        guard header.endpointCount > 0, data.count >= base else { return [] }
        for index in 0..<header.endpointCount {
            let offset = base + index * LexiconFormat.endpointBytes
            guard offset + LexiconFormat.endpointBytes <= data.count else { break }
            let start = data[offset]
            let end = data[offset + 1]
            guard start == first, end == last else { continue }
            let length = Int(data[offset + 4])
            guard length > 0, length <= 24 else { continue }
            let bytes = data.subdata(in: (offset + 8)..<(offset + 8 + length))
            if let word = String(data: bytes, encoding: .utf8) {
                found.append(word)
            }
            if found.count == 180 { break }
        }
        return found
    }

    private static func readFollowers(data: Data, header: LexiconFormat.Header) throws -> [String: [String]] {
        var offset = header.followersOffset
        var table: [String: [String]] = [:]
        table.reserveCapacity(header.followerCount)
        for _ in 0..<header.followerCount {
            guard offset < data.count else { throw LexiconError.truncated }
            let headLength = Int(data[offset])
            offset += 1
            guard headLength > 0, offset + headLength <= data.count else { throw LexiconError.truncated }
            let headBytes = data.subdata(in: offset..<(offset + headLength))
            offset += headLength
            guard offset < data.count else { throw LexiconError.truncated }
            let count = Int(data[offset])
            offset += 1
            var next: [String] = []
            next.reserveCapacity(count)
            for _ in 0..<count {
                guard offset < data.count else { throw LexiconError.truncated }
                let length = Int(data[offset])
                offset += 1
                guard offset + length <= data.count else { throw LexiconError.truncated }
                let bytes = data.subdata(in: offset..<(offset + length))
                offset += length
                if let word = String(data: bytes, encoding: .utf8) {
                    next.append(word)
                }
            }
            if let head = String(data: headBytes, encoding: .utf8) {
                table[head] = next
            }
        }
        return table
    }

    private func readNode(_ index: Int) -> NodeRecord {
        let offset = header.nodesOffset + index * LexiconFormat.nodeBytes
        return NodeRecord(
            character: data[offset],
            flags: data[offset + 1],
            rank: LexiconFormat.readUInt16(data, offset + 2),
            childStart: LexiconFormat.readUInt32(data, offset + 4),
            childCount: LexiconFormat.readUInt16(data, offset + 8)
        )
    }

    private struct NodeRecord {
        var character: UInt8
        var flags: UInt8
        var rank: UInt16
        var childStart: UInt32
        var childCount: UInt16
    }
}

public enum LexiconError: Error, Sendable, Equatable {
    case badMagic
    case truncated
}
