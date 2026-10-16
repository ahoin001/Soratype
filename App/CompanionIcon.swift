import SwiftUI

struct CompanionIcon: View {
    let systemName: String
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
            .foregroundStyle(CompanionChrome.seal)
            .frame(width: size, height: size)
            .background(
                CompanionChrome.seal.opacity(0.14),
                in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}
