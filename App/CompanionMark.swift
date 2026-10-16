import SwiftUI

/// Two keycaps leaning together. The front one carries the apricot.
struct CompanionMark: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            keycap(fill: CompanionChrome.porcelain, label: "S", ink: CompanionChrome.ink)
                .rotationEffect(.degrees(-10))
                .offset(x: -size * 0.3, y: size * 0.06)
            keycap(fill: CompanionChrome.seal, label: "a", ink: CompanionChrome.ink)
                .rotationEffect(.degrees(8))
                .offset(x: size * 0.3, y: -size * 0.06)
        }
        .frame(width: size * 1.5, height: size * 1.1)
        .accessibilityHidden(true)
    }

    private func keycap(fill: Color, label: String, ink: Color) -> some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(fill)
            .frame(width: size * 0.7, height: size * 0.78)
            .overlay {
                Text(label)
                    .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink)
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(CompanionChrome.rim, lineWidth: 1)
            }
            .shadow(color: CompanionChrome.shadow, radius: size * 0.12, y: size * 0.06)
    }
}
