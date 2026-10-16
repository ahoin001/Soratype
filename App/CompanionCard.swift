import SwiftUI

/// Warm paper, a light rim, and a tinted shadow. The same softness as a key.
struct CompanionCard<Content: View>: View {
    var padding: CGFloat = 18
    var cornerRadius: CGFloat = 26
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(CompanionChrome.porcelain)
                    .shadow(color: CompanionChrome.shadow, radius: 14, y: 6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(CompanionChrome.rim, lineWidth: 1)
            }
    }
}
