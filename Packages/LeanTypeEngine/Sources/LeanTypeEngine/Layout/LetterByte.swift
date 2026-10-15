public enum LetterByte {
    public static func byte(_ character: Character) -> UInt8? {
        guard let scalar = character.unicodeScalars.first, scalar.isASCII else { return nil }
        let value = scalar.value
        if value == 39 { return 39 }
        if (65...90).contains(value) { return UInt8(value + 32) }
        if (97...122).contains(value) { return UInt8(value) }
        return nil
    }

    public static func character(_ byte: UInt8, shifted: Bool) -> Character {
        if byte == 39 { return "'" }
        let value = shifted ? byte &- 32 : byte
        return Character(UnicodeScalar(value))
    }

    public static func spelling(_ bytes: [UInt8], shifts: UInt64 = 0) -> String {
        String(bytes.enumerated().map { index, byte in
            let shifted = index < 64 && (shifts & (UInt64(1) << index)) != 0
            return character(byte, shifted: shifted)
        })
    }
}
