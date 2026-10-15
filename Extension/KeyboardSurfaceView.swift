import UIKit
import SoratypeEngine

final class KeyboardSurfaceView: UIView {
    private var caps: [KeyCapLayer] = []
    private let trail = CAShapeLayer()
    private let popup = UILabel()
    private var fittedSize = CGSize.zero
    private var fittedGlobe = true
    private var shift = ShiftState.off
    private(set) var layout: KeyboardLayout
    var onLayout: (KeyboardLayout) -> Void
    var onTouch: ((TouchPhase, Set<UITouch>) -> Void)?
    var showsNextKeyboard = true {
        didSet {
            guard oldValue != showsNextKeyboard else { return }
            fittedSize = .zero
            setNeedsLayout()
        }
    }

    init(frame: CGRect, onLayout: @escaping (KeyboardLayout) -> Void) {
        layout = KeyboardLayout.letters(fitting: Size(width: 390, height: 220))
        self.onLayout = onLayout
        super.init(frame: frame)
        backgroundColor = KeyboardChrome.air
        isMultipleTouchEnabled = true
        trail.strokeColor = KeyboardChrome.seal.cgColor
        trail.fillColor = nil
        trail.lineWidth = 3
        trail.lineCap = .round
        trail.lineJoin = .round
        layer.addSublayer(trail)
        popup.backgroundColor = KeyboardChrome.porcelain
        popup.textColor = KeyboardChrome.ink
        popup.textAlignment = .center
        popup.font = KeyboardChrome.roundedFont(size: 28, weight: .medium)
        popup.layer.cornerRadius = 12
        popup.layer.cornerCurve = .continuous
        popup.clipsToBounds = true
        popup.isHidden = true
        popup.isUserInteractionEnabled = false
        addSubview(popup)
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The keyboard surface is created in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 1, bounds.height > 1 else { return }
        guard bounds.size != fittedSize || fittedGlobe != showsNextKeyboard || caps.isEmpty else { return }
        fittedSize = bounds.size
        fittedGlobe = showsNextKeyboard
        refit(page: layout.page)
    }

    func show(page: KeyboardPage) {
        guard page != layout.page || caps.isEmpty else { return }
        refit(page: page)
    }

    func setShift(_ shift: ShiftState) {
        self.shift = shift
        for cap in caps {
            guard let key = layout.keys.first(where: { $0.id == cap.keyID }) else { continue }
            cap.apply(key, pressed: false, shift: shift)
        }
    }

    func showPopup(for key: PlacedKey) {
        guard case .letter(let character) = key.kind else {
            hidePopup()
            return
        }
        let label = shift == .off ? String(character) : String(character).uppercased()
        popup.text = label
        let width: CGFloat = 44
        let height: CGFloat = 52
        let x = CGFloat(key.frame.center.x) - width / 2
        let y = CGFloat(key.frame.minY) - height - 6
        popup.frame = CGRect(x: x, y: y, width: width, height: height)
        popup.isHidden = false
        bringSubviewToFront(popup)
    }

    func hidePopup() {
        popup.isHidden = true
    }

    func setPressed(_ keyID: String?, pressed: Bool) {
        for cap in caps {
            guard cap.keyID == keyID, let key = layout.keys.first(where: { $0.id == keyID }) else { continue }
            cap.apply(key, pressed: pressed, shift: shift)
        }
    }

    func clearPresses() {
        for cap in caps {
            guard let key = layout.keys.first(where: { $0.id == cap.keyID }) else { continue }
            cap.apply(key, pressed: false, shift: shift)
        }
    }

    func setTrails(_ strokes: [[CGPoint]]) {
        let drawable = strokes.filter { $0.count > 1 }
        guard !drawable.isEmpty else {
            trail.path = nil
            return
        }
        let path = CGMutablePath()
        for stroke in drawable {
            path.move(to: stroke[0])
            for point in stroke.dropFirst() {
                path.addLine(to: point)
            }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trail.path = path
        CATransaction.commit()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouch?(.down, touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouch?(.move, touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouch?(.up, touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouch?(.cancel, touches)
    }

    func key(at point: CGPoint) -> PlacedKey? {
        layout.key(at: Point(x: Double(point.x), y: Double(point.y)))
    }

    private func refit(page: KeyboardPage) {
        let size = Size(width: Double(bounds.width), height: Double(bounds.height))
        let fitted: KeyboardLayout
        switch page {
        case .numbers:
            fitted = KeyboardLayout.numbers(fitting: size, showsNextKeyboard: showsNextKeyboard)
        case .punctuation:
            fitted = KeyboardLayout.punctuation(fitting: size, showsNextKeyboard: showsNextKeyboard)
        case .letters:
            fitted = KeyboardLayout.letters(fitting: size, showsNextKeyboard: showsNextKeyboard)
        }
        guard fitted != layout || caps.isEmpty else { return }
        layout = fitted
        rebuild()
        onLayout(layout)
    }

    private func rebuild() {
        caps.forEach { $0.removeFromSuperlayer() }
        caps.removeAll(keepingCapacity: true)
        for key in layout.keys {
            let cap = KeyCapLayer(key: key)
            cap.frame = CGRect(
                x: CGFloat(key.frame.origin.x),
                y: CGFloat(key.frame.origin.y),
                width: CGFloat(key.frame.size.width),
                height: CGFloat(key.frame.size.height)
            )
            cap.apply(key, pressed: false, shift: shift)
            layer.addSublayer(cap)
            caps.append(cap)
        }
        layer.addSublayer(trail)
        accessibilityElements = layout.keys.map { key in
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = key.kind == .nextKeyboard ? "Next keyboard" : key.label
            element.accessibilityFrameInContainerSpace = CGRect(
                x: CGFloat(key.frame.origin.x),
                y: CGFloat(key.frame.origin.y),
                width: CGFloat(key.frame.size.width),
                height: CGFloat(key.frame.size.height)
            )
            element.accessibilityTraits = .keyboardKey
            return element
        }
    }
}
