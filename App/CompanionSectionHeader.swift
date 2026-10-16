import SwiftUI

struct CompanionSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(CompanionChrome.font(.subheadline, weight: .semibold))
            .foregroundStyle(CompanionChrome.haze)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .accessibilityAddTraits(.isHeader)
    }
}
