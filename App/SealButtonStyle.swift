import SwiftUI

struct SealButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(CompanionChrome.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(CompanionChrome.seal.opacity(configuration.isPressed ? 0.78 : 1), in: .rect(cornerRadius: 14))
    }
}
