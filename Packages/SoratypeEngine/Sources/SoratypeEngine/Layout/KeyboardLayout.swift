/// QWERTY geometry shared by the touch surface and the replay tests.
public struct KeyboardLayout: Sendable, Equatable {
    public var page: KeyboardPage
    public var keys: [PlacedKey]
    public var size: Size
    public var midline: Double
    public var keyWidth: Double
    public var keyHeight: Double

    public init(
        page: KeyboardPage,
        keys: [PlacedKey],
        size: Size,
        midline: Double,
        keyWidth: Double,
        keyHeight: Double
    ) {
        self.page = page
        self.keys = keys
        self.size = size
        self.midline = midline
        self.keyWidth = keyWidth
        self.keyHeight = keyHeight
    }

    public static func letters(fitting size: Size, showsNextKeyboard: Bool = true) -> KeyboardLayout {
        place(
            page: .letters,
            rows: [
                letters("qwertyuiop"),
                letters("asdfghjkl"),
                [.init("shift", .shift, "⇧", 1.5)] + letters("zxcvbnm") + [
                    .init("backspace", .backspace, "⌫", 1.5),
                ],
                bottomRow(
                    leading: [.init("symbols", .symbols, "123", 1.4)],
                    showsNextKeyboard: showsNextKeyboard,
                    extra: [
                        .init("comma", .punctuation(","), ",", 1),
                        .init("space", .space, "space", 1, flexible: true),
                        .init("period", .punctuation("."), ".", 1),
                    ],
                    trailing: [.init("return", .return, "⏎", 1.5)]
                ),
            ],
            fitting: size
        )
    }

    public static func numbers(fitting size: Size, showsNextKeyboard: Bool = true) -> KeyboardLayout {
        place(
            page: .numbers,
            rows: [
                characters("1234567890", digit: true),
                characters("-/:;()$&@\""),
                characters(".,?!'") + [.init("backspace", .backspace, "⌫", 1.5)],
                bottomRow(
                    leading: [.init("letters", .letters, "ABC", 1.6)],
                    showsNextKeyboard: showsNextKeyboard,
                    extra: [.init("space", .space, "space", 1, flexible: true)],
                    trailing: [.init("return", .return, "⏎", 1.5)]
                ),
            ],
            fitting: size
        )
    }

    public static func punctuation(fitting size: Size, showsNextKeyboard: Bool = true) -> KeyboardLayout {
        place(
            page: .punctuation,
            rows: [
                characters(".,?!'\"-"),
                characters(":;()@/&"),
                characters("#+=*%"),
                bottomRow(
                    leading: [.init("letters", .letters, "ABC", 1.6)],
                    showsNextKeyboard: showsNextKeyboard,
                    extra: [.init("space", .space, "space", 1, flexible: true)],
                    trailing: [.init("return", .return, "⏎", 1.5)]
                ),
            ],
            fitting: size
        )
    }

    public func key(at point: Point) -> PlacedKey? {
        let hits = keys.filter { $0.frame.contains(point, slop: 3) }
        return hits.min { lhs, rhs in
            lhs.frame.center.distance(to: point) < rhs.frame.center.distance(to: point)
        }
    }

    public func key(for character: Character) -> PlacedKey? {
        let wanted = LetterByte.byte(character)
        return keys.first { key in
            guard let letter = key.letter, let byte = LetterByte.byte(letter) else { return false }
            return byte == wanted
        }
    }

    public func neighbors(of key: PlacedKey) -> [PlacedKey] {
        let limit = max(keyWidth, keyHeight) * 1.35
        return keys.filter { other in
            other.id != key.id && other.frame.center.distance(to: key.frame.center) <= limit
        }
    }

    public var centers: KeyCenters {
        var xs = [Double](repeating: 0, count: 27)
        var ys = [Double](repeating: 0, count: 27)
        var present = [Bool](repeating: false, count: 27)
        for key in keys {
            guard let letter = key.letter, let byte = LetterByte.byte(letter) else { continue }
            let index = KeyCenters.index(for: byte)
            guard index < 27 else { continue }
            xs[index] = key.frame.center.x
            ys[index] = key.frame.center.y
            present[index] = true
        }
        return KeyCenters(xs: xs, ys: ys, present: present, width: keyWidth, height: keyHeight)
    }

    private struct Spec {
        var id: String
        var kind: KeyKind
        var label: String
        var units: Double
        var flexible: Bool

        init(_ id: String, _ kind: KeyKind, _ label: String, _ units: Double, flexible: Bool = false) {
            self.id = id
            self.kind = kind
            self.label = label
            self.units = units
            self.flexible = flexible
        }
    }

    private static func letters(_ row: String) -> [Spec] {
        row.map { character in
            Spec(String(character), .letter(character), String(character), 1)
        }
    }

    private static func characters(_ row: String, digit: Bool = false) -> [Spec] {
        row.map { character in
            let kind: KeyKind = digit ? .digit(character) : .punctuation(character)
            return Spec("sym.\(character)", kind, String(character), 1)
        }
    }

    private static func bottomRow(
        leading: [Spec],
        showsNextKeyboard: Bool,
        extra: [Spec],
        trailing: [Spec]
    ) -> [Spec] {
        var row = leading
        if showsNextKeyboard {
            row.append(Spec("nextKeyboard", .nextKeyboard, "Next keyboard", 1.2))
        }
        row.append(contentsOf: extra)
        row.append(contentsOf: trailing)
        return row
    }

    private static func place(page: KeyboardPage, rows: [[Spec]], fitting size: Size) -> KeyboardLayout {
        let gap = 6.0
        let rowHeight = (size.height - gap * Double(rows.count + 1)) / Double(rows.count)
        let topCount = Double(rows[0].count)
        let keyWidth = (size.width - gap * (topCount + 1)) / topCount
        var placed: [PlacedKey] = []
        for (rowIndex, row) in rows.enumerated() {
            let y = gap + Double(rowIndex) * (rowHeight + gap)
            let stagger = page == .letters && rowIndex == 1
            let inset = stagger ? gap + (keyWidth + gap) / 2 : gap
            let available = size.width - inset - gap
            let gaps = gap * Double(max(row.count - 1, 0))
            let fixed = row.reduce(0.0) { total, spec in
                spec.flexible ? total : total + width(for: spec, keyWidth: keyWidth, gap: gap)
            }
            let leftover = max(0, available - fixed - gaps)
            let flexibleCount = row.filter(\.flexible).count
            var x = inset
            for (specIndex, spec) in row.enumerated() {
                if flexibleCount == 0, specIndex == row.count - 1 {
                    x += leftover
                }
                var width = width(for: spec, keyWidth: keyWidth, gap: gap)
                if spec.flexible {
                    width += leftover / Double(max(flexibleCount, 1))
                }
                placed.append(PlacedKey(
                    id: spec.id,
                    kind: spec.kind,
                    label: spec.label,
                    frame: Rect(x: x, y: y, width: width, height: rowHeight)
                ))
                x += width + gap
            }
        }
        return KeyboardLayout(
            page: page,
            keys: placed,
            size: size,
            midline: size.width / 2,
            keyWidth: keyWidth,
            keyHeight: rowHeight
        )
    }

    private static func width(for spec: Spec, keyWidth: Double, gap: Double) -> Double {
        spec.units * keyWidth + gap * (spec.units - 1)
    }
}
