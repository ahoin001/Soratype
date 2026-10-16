import SwiftUI

/// An apricot pill that settles under the finger.
struct SealButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CompanionChrome.font(.headline, weight: .semibold))
            .foregroundStyle(CompanionChrome.ink)
            .padding(.horizontal, 22)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background {
                Capsule(style: .continuous)
                    .fill(CompanionChrome.seal)
                    .shadow(color: CompanionChrome.seal.opacity(0.35), radius: 12, y: 6)
            }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(reduceMotion ? nil : CompanionMotion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SealButtonStyle {
    static var seal: SealButtonStyle { SealButtonStyle() }
}
