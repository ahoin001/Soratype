import Foundation

public struct EndpointWord: Sendable, Equatable {
    public var text: String
    public var rank: UInt16

    public init(text: String, rank: UInt16) {
        self.text = text
        self.rank = rank
    }
}

public enum LexiconFormat {
    public static let magic = Data("LTLEX1\0\0".utf8)
    public static let headerBytes = 64
    public static let nodeBytes = 16
    public static let endpointBytes = 32
    public static let version: UInt16 = 1

    public struct Header: Sendable, Equatable {
        public var wordCount: Int
        public var nodeCount: Int
        public var nodesOffset: Int
        public var endpointOffset: Int
        public var endpointCount: Int
    }

    public static func header(in data: Data) -> Header? {
        guard data.count >= headerBytes, data.prefix(8) == magic else { return nil }
        let version = readUInt16(data, 8)
        guard version == Self.version else { return nil }
        return Header(
            wordCount: Int(readUInt32(data, 12)),
            nodeCount: Int(readUInt32(data, 16)),
            nodesOffset: Int(readUInt32(data, 20)),
            endpointOffset: Int(readUInt32(data, 24)),
            endpointCount: Int(readUInt32(data, 28))
        )
    }

    public static func readUInt16(_ data: Data, _ offset: Int) -> UInt16 {
        data.withUnsafeBytes { raw in
            raw.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
        }
    }

    public static func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        data.withUnsafeBytes { raw in
            raw.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
        }
    }
}
