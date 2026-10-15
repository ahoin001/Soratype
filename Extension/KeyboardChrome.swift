import UIKit

/// Cool air, warm paper, one apricot note. Keep in step with CompanionChrome.
nonisolated enum KeyboardChrome {
    static let air = UIColor(red: 0.851, green: 0.894, blue: 0.949, alpha: 1)
    static let porcelain = UIColor(red: 1, green: 0.984, blue: 0.965, alpha: 1)
    static let cloud = UIColor(red: 0.761, green: 0.827, blue: 0.910, alpha: 1)
    static let ink = UIColor(red: 0.071, green: 0.102, blue: 0.149, alpha: 1)
    static let seal = UIColor(red: 0.910, green: 0.416, blue: 0.200, alpha: 1)
    static let pressedPorcelain = UIColor(red: 0.941, green: 0.902, blue: 0.847, alpha: 1)
    static let pressedCloud = UIColor(red: 0.663, green: 0.749, blue: 0.855, alpha: 1)
    static let trough = UIColor(red: 0.106, green: 0.141, blue: 0.200, alpha: 1)
    static let troughText = porcelain
    static let radius: CGFloat = 14
    static let gap: CGFloat = 6
    static let stripHeight: CGFloat = 56
    static let boardHeight: CGFloat = 304
    static let compactBoardHeight: CGFloat = 228

    static func capRadius(height: CGFloat) -> CGFloat {
        min(height * 0.38, 18)
    }

    static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}
