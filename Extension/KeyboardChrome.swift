import UIKit

nonisolated enum KeyboardChrome {
    static let paper = UIColor(red: 0.957, green: 0.945, blue: 0.925, alpha: 1)
    static let cap = UIColor.white
    static let mist = UIColor(red: 0.906, green: 0.886, blue: 0.855, alpha: 1)
    static let ink = UIColor(red: 0.173, green: 0.165, blue: 0.157, alpha: 1)
    static let pressed = UIColor(red: 0.847, green: 0.820, blue: 0.776, alpha: 1)
    static let radius: CGFloat = 14
    static let gap: CGFloat = 6
    static let stripHeight: CGFloat = 44

    static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}
