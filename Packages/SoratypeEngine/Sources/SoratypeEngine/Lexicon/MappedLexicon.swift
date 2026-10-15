import Foundation

/// One shared mapping of the word list. The keyboard and the decoder both hold this object, so it stays a class.
public final class MappedLexicon: Lexicon, Sendable {
    public let wordCount: Int
    public let root = LexiconNode(index: 0)
    private let data: Data
    private let header: LexiconFormat.Header

    public init(data: Data) throws {
        guard let header = LexiconFormat.header(in: data) else {
            throw LexiconError.badMagic
        }
        let nodesEnd = header.nodesOffset + header.nodeCount * LexiconFormat.nodeBytes
        guard data.count >= nodesEnd else { throw LexiconError.truncated }
        self.data = data
        self.header = header
        self.wordCount = header.wordCount
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
        return record.flags & 1 == 1 ? record.rank : 0
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
