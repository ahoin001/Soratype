import UIKit
import SoratypeEngine

final class SuggestionStripView: UIView {
    var onChip: (Int) -> Void
    var onReject: (Int) -> Void
    private let sheen = UIView()
    private let wash = UIView()
    private let track = UIView()
    private var slots: [ChipSlot] = []
    private var shown = Strip.empty

    init(onChip: @escaping (Int) -> Void) {
        self.onChip = onChip
        self.onReject = { _ in }
        super.init(frame: .zero)
        backgroundColor = KeyboardChrome.trough
        clipsToBounds = true
        isAccessibilityElement = false

        wash.backgroundColor = KeyboardChrome.seal
        wash.alpha = 0
        wash.isUserInteractionEnabled = false
        addSubview(wash)

        track.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        track.layer.cornerRadius = 14
        track.layer.cornerCurve = .continuous
        track.isUserInteractionEnabled = false
        addSubview(track)

        sheen.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        sheen.isUserInteractionEnabled = false
        addSubview(sheen)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The strip is created in code")
    }

    func show(_ strip: Strip) {
        guard strip != shown else { return }
        let morph = !shown.chips.isEmpty && !strip.chips.isEmpty && !UIAccessibility.isReduceMotionEnabled
        let previousIDs = Set(slots.map(\.chipID))
        shown = strip
        syncSlots()
        let frames = slotFrames()
        for (index, slot) in slots.enumerated() where !previousIDs.contains(slot.chipID) {
            if index < frames.count {
                slot.frame = frames[index]
            }
            slot.alpha = 0
        }
        let washAlpha: CGFloat = strip.preview && !strip.chips.isEmpty ? 0.18 : 0
        let changes = {
            self.layoutSlots()
            self.styleSlots()
            self.wash.alpha = washAlpha
            for slot in self.slots {
                slot.alpha = 1
            }
        }
        if morph {
            UIView.animate(
                withDuration: 0.14,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction],
                animations: changes
            )
        } else {
            changes()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        sheen.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 1)
        wash.frame = bounds
        track.frame = bounds.insetBy(dx: 8, dy: 8)
        layoutSlots()
    }

    private func syncSlots() {
        let chips = shown.chips
        var unused = slots
        var next: [ChipSlot] = []
        next.reserveCapacity(chips.count)
        for (index, chip) in chips.enumerated() {
            let slot: ChipSlot
            if let match = unused.firstIndex(where: { $0.chipID == chip.id }) {
                slot = unused.remove(at: match)
            } else {
                slot = ChipSlot()
                slot.addAction(UIAction { [weak self, weak slot] _ in
                    guard let self, let slot else { return }
                    self.onChip(slot.index)
                }, for: .touchUpInside)
                slot.onLongPress = { [weak self] index in
                    self?.onReject(index)
                }
                slot.chipID = chip.id
                insertSubview(slot, belowSubview: sheen)
            }
            slot.index = index
            slot.accessibilityLabel = chip.text
            slot.title.text = chip.text
            slot.title.font = KeyboardChrome.roundedFont(
                size: 16,
                weight: chip.role == .leader ? .semibold : .regular
            )
            next.append(slot)
        }
        for slot in next {
            slot.onLongPress = { [weak self] index in
                self?.onReject(index)
            }
        }
        unused.forEach { $0.removeFromSuperview() }
        slots = next
    }

    private func layoutSlots() {
        let frames = slotFrames()
        for (index, slot) in slots.enumerated() where index < frames.count {
            slot.frame = frames[index]
        }
    }

    private func styleSlots() {
        for (index, slot) in slots.enumerated() {
            guard shown.chips.indices.contains(index) else { continue }
            let chip = shown.chips[index]
            let leader = chip.role == .leader
            let quiet = shown.highlighted == nil && leader
            slot.backgroundColor = leader ? KeyboardChrome.seal.withAlphaComponent(quiet ? 0.75 : 1) : UIColor.white.withAlphaComponent(0.12)
            slot.title.textColor = leader ? KeyboardChrome.ink : KeyboardChrome.troughText
        }
    }

    private func slotFrames() -> [CGRect] {
        let area = bounds.insetBy(dx: 8, dy: 8)
        let count = slots.count
        guard count > 0, area.width > 1, area.height > 1 else { return [] }
        if count == 1 {
            return [area]
        }
        let gap: CGFloat = 6
        let usable = area.width - gap * CGFloat(count - 1)
        let leaderIndex = shown.chips.firstIndex { $0.role == .leader } ?? 0
        let leaderWidth = usable * 0.5
        let otherWidth = (usable - leaderWidth) / CGFloat(count - 1)
        var x = area.minX
        var frames: [CGRect] = []
        frames.reserveCapacity(count)
        for index in 0..<count {
            let width = index == leaderIndex ? leaderWidth : otherWidth
            frames.append(CGRect(x: x, y: area.minY, width: width, height: area.height))
            x += width + gap
        }
        return frames
    }
}

private final class ChipSlot: UIControl {
    var chipID = ""
    var index = 0
    let title = UILabel()
    private let press = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        clipsToBounds = true
        press.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        press.isUserInteractionEnabled = false
        press.alpha = 0
        title.textAlignment = .center
        title.adjustsFontForContentSizeCategory = false
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.7
        title.lineBreakMode = .byTruncatingTail
        addSubview(press)
        addSubview(title)
        isAccessibilityElement = true
        accessibilityTraits = .button
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
        hold.minimumPressDuration = 0.45
        addGestureRecognizer(hold)
    }

    var onLongPress: ((Int) -> Void)?

    @objc private func held(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        onLongPress?(index)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Chip slots are created in code")
    }

    override var isHighlighted: Bool {
        didSet {
            press.alpha = isHighlighted ? 1 : 0
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        press.frame = bounds
        title.frame = bounds.insetBy(dx: 10, dy: 4)
    }
}
