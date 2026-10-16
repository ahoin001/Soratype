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
            for slot in self.slots where !slot.isHiding {
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
                slot.chipID = chip.id
                insertSubview(slot, belowSubview: sheen)
            }
            slot.onTap = { [weak self] index in
                self?.onChip(index)
            }
            slot.onHide = { [weak self] index in
                self?.onReject(index)
            }
            slot.index = index
            slot.role = chip.role
            slot.accessibilityTraits = chip.role == .context ? .staticText : .button
            slot.accessibilityHint = chip.role == .context ? nil : "Tap to use. Hold to hide."
            slot.showWord(chip.text)
            if !slot.isHolding {
                slot.accessibilityLabel = chip.text
                slot.transform = .identity
            }
            next.append(slot)
        }
        unused.forEach { slot in
            guard !UIAccessibility.isReduceMotionEnabled else {
                slot.removeFromSuperview()
                return
            }
            UIView.animate(
                withDuration: 0.14,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState]
            ) {
                slot.alpha = 0
                slot.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            } completion: { _ in
                slot.removeFromSuperview()
            }
        }
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
            let quiet = shown.highlighted == nil && chip.role == .leader
            let color: UIColor
            switch chip.role {
            case .follower:
                slot.backgroundColor = KeyboardChrome.seal
                color = KeyboardChrome.ink
                slot.title.font = KeyboardChrome.roundedFont(size: 16, weight: .semibold)
            case .leader where shown.preview:
                slot.backgroundColor = KeyboardChrome.seal.withAlphaComponent(quiet ? 0.75 : 1)
                color = KeyboardChrome.ink
                slot.title.font = KeyboardChrome.roundedFont(size: 16, weight: .semibold)
            case .context:
                slot.backgroundColor = .clear
                color = KeyboardChrome.troughText.withAlphaComponent(0.55)
                slot.title.font = KeyboardChrome.roundedFont(size: 15, weight: .regular)
            default:
                slot.backgroundColor = UIColor.white.withAlphaComponent(0.12)
                color = KeyboardChrome.troughText
                slot.title.font = KeyboardChrome.roundedFont(size: 16, weight: .regular)
            }
            slot.applyTitleColor(color)
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
        let emphasis = shown.chips.firstIndex { $0.role == .follower }
            ?? shown.chips.firstIndex { $0.role == .leader }
        let emphasisWidth = emphasis == nil ? usable / CGFloat(count) : usable * 0.5
        let otherWidth = emphasis == nil ? emphasisWidth : (usable - emphasisWidth) / CGFloat(max(count - 1, 1))
        var x = area.minX
        var frames: [CGRect] = []
        frames.reserveCapacity(count)
        for index in 0..<count {
            let width = index == emphasis ? emphasisWidth : otherWidth
            frames.append(CGRect(x: x, y: area.minY, width: width, height: area.height))
            x += width + gap
        }
        return frames
    }
}

private final class ChipSlot: UIControl {
    var chipID = ""
    var index = 0
    var role = ChipRole.alternative
    var onTap: ((Int) -> Void)?
    var onHide: ((Int) -> Void)?
    let title = UILabel()
    private let fill = UIView()
    private var restingTitle = ""
    private var restingColor = KeyboardChrome.troughText
    private var pressTask: Task<Void, Never>?
    private var holding = false
    private var hiding = false
    private let impact = UIImpactFeedbackGenerator(style: .light)

    var isHolding: Bool { holding || hiding }
    var isHiding: Bool { hiding }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        clipsToBounds = true
        fill.backgroundColor = KeyboardChrome.seal
        fill.isUserInteractionEnabled = false
        fill.alpha = 0
        title.textAlignment = .center
        title.adjustsFontForContentSizeCategory = false
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.7
        title.lineBreakMode = .byTruncatingTail
        addSubview(fill)
        addSubview(title)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Chip slots are created in code")
    }

    func showWord(_ word: String) {
        restingTitle = word
        guard !isHolding else { return }
        title.text = word
    }

    func applyTitleColor(_ color: UIColor) {
        restingColor = color
        guard !isHolding else { return }
        title.textColor = color
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !holding, !hiding else { return }
        holding = true
        impact.prepare()
        if !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(
                withDuration: 0.12,
                delay: 0,
                options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
            ) {
                self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            }
        }
        guard role != .context else { return }
        pressTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, self.holding, !self.hiding else { return }
            self.revealHide()
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, self.holding, !self.hiding else { return }
            self.commitHide()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard holding, !hiding else { return }
        let inside = touches.contains { bounds.contains($0.location(in: self)) }
        if !inside {
            endPress(performTap: false)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let inside = touches.contains { bounds.contains($0.location(in: self)) }
        endPress(performTap: inside)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endPress(performTap: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fill.frame = bounds
        title.frame = bounds.insetBy(dx: 10, dy: 4)
    }

    private func revealHide() {
        title.text = "Hide"
        accessibilityLabel = "Hide"
        title.textColor = KeyboardChrome.ink
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
        ) {
            self.fill.alpha = 1
        }
    }

    private func commitHide() {
        hiding = true
        holding = false
        title.text = "Hidden"
        accessibilityLabel = "Hidden"
        impact.impactOccurred()
        let index = self.index
        let finish = { self.onHide?(index) }
        guard !UIAccessibility.isReduceMotionEnabled else {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                finish()
            }
            return
        }
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
            self.transform = CGAffineTransform(scaleX: 0.02, y: 0.02)
            self.alpha = 0
        } completion: { _ in
            finish()
        }
    }

    private func endPress(performTap: Bool) {
        guard !hiding else { return }
        pressTask?.cancel()
        pressTask = nil
        let shouldTap = performTap && holding && role != .context
        holding = false
        title.text = restingTitle
        accessibilityLabel = restingTitle
        title.textColor = restingColor
        fill.alpha = 0
        if UIAccessibility.isReduceMotionEnabled {
            transform = .identity
        } else {
            UIView.animate(
                withDuration: 0.12,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
            ) {
                self.transform = .identity
            }
        }
        if shouldTap {
            onTap?(index)
        }
    }
}
