import SwiftUI

struct CompanionLinkRow: View {
    let systemImage: String
    let title: String
    var detail: String?

    var body: some View {
        HStack(spacing: 14) {
            CompanionIcon(systemName: systemImage, size: 34)
            CompanionRowText(title: title, detail: detail)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(CompanionChrome.haze.opacity(0.7))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
