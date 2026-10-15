import Foundation
import SoratypeEngine

public enum LexiconCompiler {
    public static func compile(
        wordsInFrequencyOrder words: [String],
        offensive: Set<String> = [],
        followers: [String: [String]] = [:]
    ) -> Data {
        var builder = Builder()
        var seen = Set<String>()
        var written: [String] = []
        let blocked = Set(offensive.map { $0.lowercased() })
        for (offset, raw) in words.enumerated() {
            let word = raw.lowercased()
            guard !word.isEmpty, seen.insert(word).inserted else { continue }
            let bytes = Array(word.utf8)
            guard bytes.allSatisfy({ $0 == 39 || (97...122).contains($0) }) else { continue }
            builder.insert(bytes, rank: UInt16(min(offset + 1, Int(UInt16.max))), offensive: blocked.contains(word))
            written.append(word)
        }
        let known = Set(written)
        var packedFollowers: [String: [String]] = [:]
        for (head, next) in followers {
            let key = head.lowercased()
            guard known.contains(key) else { continue }
            let kept = next.map { $0.lowercased() }.filter { known.contains($0) }
            guard !kept.isEmpty else { continue }
            packedFollowers[key] = Array(kept.prefix(4))
        }
        return builder.serialize(words: written, followers: packedFollowers)
    }

    public static func compile(
        wordList: String,
        curated: String = "",
        offensive: String = "",
        followers: String = ""
    ) -> Data {
        let curatedWords = lines(curated)
        let bulk = lines(wordList)
        let offensiveWords = lines(offensive)
        var ordered = curatedWords
        var seen = Set(curatedWords)
        for word in bulk where seen.insert(word).inserted {
            ordered.append(word)
        }
        for word in offensiveWords where seen.insert(word).inserted {
            ordered.append(word)
        }
        return compile(
            wordsInFrequencyOrder: ordered,
            offensive: Set(offensiveWords),
            followers: parseFollowers(followers)
        )
    }

    private static func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
            let word = trimmed.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
            let lowered = word.lowercased()
            let bytes = Array(lowered.utf8)
            guard !bytes.isEmpty, bytes.allSatisfy({ $0 == 39 || (97...122).contains($0) }) else { return nil }
            return lowered
        }
    }

    private static func parseFollowers(_ text: String) -> [String: [String]] {
        var table: [String: [String]] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 2 else { continue }
            let head = parts[0].lowercased()
            let next = parts[1].lowercased()
            guard head != next else { continue }
            var list = table[head] ?? []
            if list.count < 4, !list.contains(next) {
                list.append(next)
                table[head] = list
            }
        }
        return table
    }

    private struct SourceNode {
        var character: UInt8 = 0
        var rank: UInt16 = 0
        var flags: UInt8 = 0
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

        mutating func insert(_ bytes: [UInt8], rank: UInt16, offensive: Bool) {
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
                nodes[index].flags = LexiconFormat.wordFlag
                wordCount += 1
            }
            if offensive {
                nodes[index].flags |= LexiconFormat.offensiveFlag
            }
        }

        func serialize(words: [String], followers: [String: [String]]) -> Data {
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
                    packed[index].flags = nodes[source].flags
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

            var followerBlob = Data()
            let heads = followers.keys.sorted()
            for head in heads {
                guard let next = followers[head], !next.isEmpty else { continue }
                append(&followerBlob, head)
                followerBlob.append(UInt8(next.count))
                for word in next {
                    append(&followerBlob, word)
                }
            }

            let nodesOffset = LexiconFormat.headerBytes
            let endpointOffset = nodesOffset + packed.count * LexiconFormat.nodeBytes
            let followersOffset = endpointOffset + endpoints.count * LexiconFormat.endpointBytes
            var data = Data(count: followersOffset + followerBlob.count)
            data.replaceSubrange(0..<8, with: LexiconFormat.magic)
            write(LexiconFormat.version, to: &data, at: 8)
            write(UInt16(LexiconFormat.headerBytes), to: &data, at: 10)
            write(UInt32(wordCount), to: &data, at: 12)
            write(UInt32(packed.count), to: &data, at: 16)
            write(UInt32(nodesOffset), to: &data, at: 20)
            write(UInt32(endpointOffset), to: &data, at: 24)
            write(UInt32(endpoints.count), to: &data, at: 28)
            write(UInt32(followersOffset), to: &data, at: 32)
            write(UInt32(heads.count), to: &data, at: 36)
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
            if !followerBlob.isEmpty {
                data.replaceSubrange(followersOffset..<(followersOffset + followerBlob.count), with: followerBlob)
            }
            return data
        }

        private func append(_ data: inout Data, _ word: String) {
            let bytes = Array(word.utf8.prefix(24))
            data.append(UInt8(bytes.count))
            data.append(contentsOf: bytes)
        }
    }

    private static func write(_ value: UInt16, to data: inout Data, at offset: Int) {
        var bytes = data.mutableBytes
        bytes.storeBytes(of: value.littleEndian, toByteOffset: offset, as: UInt16.self)
    }

    private static func write(_ value: UInt32, to data: inout Data, at offset: Int) {
        var bytes = data.mutableBytes
        bytes.storeBytes(of: value.littleEndian, toByteOffset: offset, as: UInt32.self)
    }
}
