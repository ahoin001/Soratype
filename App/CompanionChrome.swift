import SwiftUI

/// Cool air, warm paper, one apricot note. Keep in step with KeyboardChrome.
enum CompanionChrome {
    static let air = Color(red: 0.851, green: 0.894, blue: 0.949)
    static let porcelain = Color(red: 1, green: 0.984, blue: 0.965)
    static let ink = Color(red: 0.071, green: 0.102, blue: 0.149)
    static let haze = Color(red: 0.235, green: 0.314, blue: 0.392)
    static let seal = Color(red: 0.910, green: 0.416, blue: 0.200)
    static let caution = Color(red: 0.659, green: 0.165, blue: 0.149)
}

extension View {
    func companionCard() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CompanionChrome.porcelain, in: .rect(cornerRadius: 14))
            .shadow(color: CompanionChrome.ink.opacity(0.08), radius: 10, y: 4)
    }
}
