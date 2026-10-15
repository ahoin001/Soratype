import CoreText
import UIKit
import SoratypeEngine

nonisolated final class KeyCapLayer: CALayer {
    let keyID: String
    private let text = CATextLayer()

    init(key: PlacedKey) {
        keyID = key.id
        super.init()
        contentsScale = UIScreen.main.scale
        text.contentsScale = UIScreen.main.scale
        text.alignmentMode = .center
        text.truncationMode = .none
        text.isWrapped = false
        text.foregroundColor = KeyboardChrome.ink.cgColor
        addSublayer(text)
        cornerRadius = KeyboardChrome.radius
        cornerCurve = .continuous
        shadowColor = UIColor.black.cgColor
        shadowOpacity = 0.08
        shadowRadius = 6
        shadowOffset = CGSize(width: 0, height: 2)
        apply(key, pressed: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Key caps are built from the layout")
    }

    func apply(_ key: PlacedKey, pressed: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let fill = pressed ? KeyboardChrome.pressed : (key.kind.isStrokeEligible || isPlain(key.kind) ? KeyboardChrome.cap : KeyboardChrome.mist)
        backgroundColor = fill.cgColor
        let size: CGFloat = key.kind == .space ? 15 : 22
        text.font = KeyboardChrome.roundedFont(size: size, weight: .regular) as CTFont
        text.fontSize = size
        text.string = key.label
        text.frame = CGRect(x: 0, y: (bounds.height - size - 4) / 2, width: bounds.width, height: size + 4)
        CATransaction.commit()
    }

    private func isPlain(_ kind: KeyKind) -> Bool {
        switch kind {
        case .letter, .digit, .punctuation: true
        default: false
        }
    }
}
