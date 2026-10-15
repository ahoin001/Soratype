import Foundation
import LeanTypeEngine

public enum LexiconCompiler {
    public static func compile(wordsInFrequencyOrder words: [String]) -> Data {
        var builder = Builder()
        var seen = Set<String>()
        var written: [String] = []
        for (offset, raw) in words.enumerated() {
            let word = raw.lowercased()
            guard !word.isEmpty, seen.insert(word).inserted else { continue }
            let bytes = Array(word.utf8)
            guard bytes.allSatisfy({ $0 == 39 || (97...122).contains($0) }) else { continue }
            builder.insert(bytes, rank: UInt16(min(offset + 1, Int(UInt16.max))))
            written.append(word)
        }
        return builder.serialize(words: written)
    }

    public static func compile(wordList: String) -> Data {
        let words = wordList.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
            return trimmed.split(whereSeparator: \.isWhitespace).first.map(String.init)
        }
        return compile(wordsInFrequencyOrder: words)
    }

    private struct SourceNode {
        var character: UInt8 = 0
        var rank: UInt16 = 0
        var children: [UInt8: Int] = [:]
    }

    private struct PackedNode {
        var character: UInt8 = 0
        var flags: UInt8 = 0
        var rank: UInt16 = 0
        var childStart: UInt32 = 0
        var childCount: UInt16 = 0
    }

    private struct Builder {
        var nodes: [SourceNode] = [SourceNode()]
        var wordCount = 0

        mutating func insert(_ bytes: [UInt8], rank: UInt16) {
            var index = 0
            for byte in bytes {
                if let child = nodes[index].children[byte] {
                    index = child
                } else {
                    let child = nodes.count
                    var created = SourceNode()
                    created.character = byte
                    nodes.append(created)
                    nodes[index].children[byte] = child
                    index = child
                }
            }
            if nodes[index].rank == 0 {
                nodes[index].rank = rank
                wordCount += 1
            }
        }

        func serialize(words: [String]) -> Data {
            var packed = Array(repeating: PackedNode(), count: nodes.count)
            var next = 1
            func assign(_ source: Int, at index: Int) {
                let children = nodes[source].children.sorted { $0.key < $1.key }
                let start = next
                next += children.count
                for (offset, child) in children.enumerated() {
                    packed[start + offset].character = child.key
                    assign(child.value, at: start + offset)
                }
                packed[index].character = index == 0 ? 0 : nodes[source].character
                packed[index].childStart = UInt32(start)
                packed[index].childCount = UInt16(children.count)
                if nodes[source].rank > 0 {
                    packed[index].rank = nodes[source].rank
                    packed[index].flags = 1
                }
            }
            assign(0, at: 0)

            var endpoints: [(UInt8, UInt8, UInt16, [UInt8])] = []
            var buckets: [UInt16: Int] = [:]
            for word in words {
                let bytes = Array(word.utf8)
                guard let first = bytes.first, let last = bytes.last, bytes.count <= 24 else { continue }
                let key = UInt16(first) << 8 | UInt16(last)
                let count = buckets[key, default: 0]
                guard count < 180 else { continue }
                buckets[key] = count + 1
                let rank = UInt16(min(endpoints.count + 1, Int(UInt16.max)))
                endpoints.append((first, last, rank, bytes))
            }

            let nodesOffset = LexiconFormat.headerBytes
            let endpointOffset = nodesOffset + packed.count * LexiconFormat.nodeBytes
            var data = Data(count: endpointOffset + endpoints.count * LexiconFormat.endpointBytes)
            data.replaceSubrange(0..<8, with: LexiconFormat.magic)
            write(UInt16(1), to: &data, at: 8)
            write(UInt16(LexiconFormat.headerBytes), to: &data, at: 10)
            write(UInt32(wordCount), to: &data, at: 12)
            write(UInt32(packed.count), to: &data, at: 16)
            write(UInt32(nodesOffset), to: &data, at: 20)
            write(UInt32(endpointOffset), to: &data, at: 24)
            write(UInt32(endpoints.count), to: &data, at: 28)
            for (index, node) in packed.enumerated() {
                let offset = nodesOffset + index * LexiconFormat.nodeBytes
                data[offset] = node.character
                data[offset + 1] = node.flags
                write(node.rank, to: &data, at: offset + 2)
                write(node.childStart, to: &data, at: offset + 4)
                write(node.childCount, to: &data, at: offset + 8)
            }
            for (index, endpoint) in endpoints.enumerated() {
                let offset = endpointOffset + index * LexiconFormat.endpointBytes
                data[offset] = endpoint.0
                data[offset + 1] = endpoint.1
                write(endpoint.2, to: &data, at: offset + 2)
                data[offset + 4] = UInt8(endpoint.3.count)
                for (byteIndex, byte) in endpoint.3.enumerated() {
                    data[offset + 8 + byteIndex] = byte
                }
            }
            return data
        }
    }

    private static func write(_ value: UInt16, to data: inout Data, at offset: Int) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.replaceSubrange(offset..<(offset + 2), with: $0) }
    }

    private static func write(_ value: UInt32, to data: inout Data, at offset: Int) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.replaceSubrange(offset..<(offset + 4), with: $0) }
    }
}
