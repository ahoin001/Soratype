import UIKit
import SoratypeEngine

final class SuggestionStripView: UIView {
    var onChip: (Int) -> Void
    private var buttons: [UIButton] = []
    private var shown = Strip.empty

    init(onChip: @escaping (Int) -> Void) {
        self.onChip = onChip
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The strip is created in code")
    }

    func show(_ strip: Strip) {
        guard strip != shown else { return }
        shown = strip
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll(keepingCapacity: true)
        for (index, chip) in strip.chips.enumerated() {
            var configuration = UIButton.Configuration.plain()
            configuration.title = chip.text
            configuration.baseForegroundColor = KeyboardChrome.ink
            configuration.background.backgroundColor = index == strip.highlighted ? .white : KeyboardChrome.mist
            configuration.background.cornerRadius = 14
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = KeyboardChrome.roundedFont(size: 16, weight: chip.role == .leader ? .semibold : .regular)
                return outgoing
            }
            let button = UIButton(configuration: configuration)
            button.tag = index
            button.addAction(UIAction { [weak self] _ in
                self?.onChip(index)
            }, for: .touchUpInside)
            button.accessibilityLabel = chip.text
            addSubview(button)
            buttons.append(button)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !buttons.isEmpty else { return }
        let widths = buttons.map { button -> CGFloat in
            let title = button.configuration?.title ?? ""
            let font = KeyboardChrome.roundedFont(size: 16, weight: .regular)
            let text = (title as NSString).size(withAttributes: [.font: font])
            return text.width + 28
        }
        let total = widths.reduce(0, +) + CGFloat(max(buttons.count - 1, 0)) * 8
        var x = max(12, (bounds.width - total) / 2)
        for (index, button) in buttons.enumerated() {
            let width = widths[index]
            button.frame = CGRect(x: x, y: 6, width: width, height: bounds.height - 12)
            x += width + 8
        }
    }
}
