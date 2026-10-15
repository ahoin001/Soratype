import CoreText
import UIKit
import SoratypeEngine

nonisolated final class KeyCapLayer: CALayer {
    let keyID: String
    private let text = CATextLayer()
    private let icon = CALayer()

    init(key: PlacedKey) {
        keyID = key.id
        super.init()
        contentsScale = UIScreen.main.scale
        text.contentsScale = UIScreen.main.scale
        text.alignmentMode = .center
        text.truncationMode = .none
        text.isWrapped = false
        text.foregroundColor = KeyboardChrome.ink.cgColor
        icon.contentsGravity = .resizeAspect
        icon.contentsScale = UIScreen.main.scale
        addSublayer(text)
        addSublayer(icon)
        cornerCurve = .continuous
        shadowColor = KeyboardChrome.ink.cgColor
        shadowOpacity = 0.10
        shadowRadius = 5
        shadowOffset = CGSize(width: 0, height: 2)
        apply(key, pressed: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Key caps are built from the layout")
    }

    func apply(_ key: PlacedKey, pressed: Bool, shift: ShiftState = .off) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundColor = fill(for: key, pressed: pressed, shift: shift).cgColor
        cornerRadius = KeyboardChrome.capRadius(height: bounds.height)
        if key.kind == .nextKeyboard {
            text.string = nil
            icon.isHidden = false
            let side = min(bounds.width, bounds.height) * 0.42
            icon.frame = CGRect(
                x: (bounds.width - side) / 2,
                y: (bounds.height - side) / 2,
                width: side,
                height: side
            )
            icon.contents = MainActor.assumeIsolated { Self.globeImage() }
        } else {
            icon.isHidden = true
            icon.contents = nil
            let size: CGFloat = key.kind == .space ? 15 : 22
            text.font = KeyboardChrome.roundedFont(size: size, weight: .regular) as CTFont
            text.fontSize = size
            text.string = label(for: key, shift: shift)
            text.frame = CGRect(x: 0, y: (bounds.height - size - 4) / 2, width: bounds.width, height: size + 4)
        }
        CATransaction.commit()
    }

    private func label(for key: PlacedKey, shift: ShiftState) -> String {
        switch key.kind {
        case .letter(let character):
            shift == .off ? String(character) : String(character).uppercased()
        case .shift:
            shift == .locked ? "⇪" : "⇧"
        default:
            key.label
        }
    }

    private func fill(for key: PlacedKey, pressed: Bool, shift: ShiftState) -> UIColor {
        if case .shift = key.kind, !pressed {
            switch shift {
            case .locked:
                return KeyboardChrome.seal
            case .once:
                return KeyboardChrome.seal.withAlphaComponent(0.55)
            case .off:
                break
            }
        }
        let utility = !key.kind.isStrokeEligible && !isPlain(key.kind)
        if pressed {
            return utility ? KeyboardChrome.pressedCloud : KeyboardChrome.pressedPorcelain
        }
        return utility ? KeyboardChrome.cloud : KeyboardChrome.porcelain
    }

    private func isPlain(_ kind: KeyKind) -> Bool {
        switch kind {
        case .letter, .digit, .punctuation: true
        default: false
        }
    }

    @MainActor
    private static func globeImage() -> CGImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        guard let symbol = UIImage(systemName: "globe", withConfiguration: configuration)?
            .withTintColor(KeyboardChrome.ink, renderingMode: .alwaysOriginal)
        else { return nil }
        if let image = symbol.cgImage { return image }
        let size = symbol.size
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            symbol.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}
