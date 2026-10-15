import UIKit
import SoratypeEngine

final class KeyboardSurfaceView: UIView {
    private var caps: [KeyCapLayer] = []
    private let trail = CAShapeLayer()
    private var fittedSize = CGSize.zero
    private(set) var layout: KeyboardLayout
    var onLayout: (KeyboardLayout) -> Void
    var onTouch: ((TouchPhase, Set<UITouch>) -> Void)?

    init(frame: CGRect, onLayout: @escaping (KeyboardLayout) -> Void) {
        layout = KeyboardLayout.letters(fitting: Size(width: 390, height: 220))
        self.onLayout = onLayout
        super.init(frame: frame)
        backgroundColor = KeyboardChrome.paper
        isMultipleTouchEnabled = true
        trail.strokeColor = KeyboardChrome.ink.withAlphaComponent(0.28).cgColor
        trail.fillColor = nil
        trail.lineWidth = 3
        trail.lineCap = .round
        trail.lineJoin = .round
        layer.addSublayer(trail)
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The keyboard surface is created in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 1, bounds.height > 1 else { return }
        guard bounds.size != fittedSize || caps.isEmpty else { return }
        fittedSize = bounds.size
        refit(page: layout.page)
    }

    func show(page: KeyboardPage) {
        guard page != layout.page || caps.isEmpty else { return }
        refit(page: page)
    }

    func setPressed(_ keyID: String?, pressed: Bool) {
        for cap in caps {
            guard cap.keyID == keyID, let key = layout.keys.first(where: { $0.id == keyID }) else { continue }
            cap.apply(key, pressed: pressed)
        }
    }

    func clearPresses() {
        for cap in caps {
            guard let key = layout.keys.first(where: { $0.id == cap.keyID }) else { continue }
            cap.apply(key, pressed: false)
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
        let fitted = page == .numbers ? KeyboardLayout.numbers(fitting: size) : KeyboardLayout.letters(fitting: size)
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
            cap.apply(key, pressed: false)
            layer.addSublayer(cap)
            caps.append(cap)
        }
        layer.addSublayer(trail)
        accessibilityElements = layout.keys.map { key in
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityLabel = key.label
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
