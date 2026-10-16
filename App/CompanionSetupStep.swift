import SwiftUI

struct CompanionSetupStep: View {
    let number: Int
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number, format: .number)
                .font(CompanionChrome.font(.footnote, weight: .bold))
                .foregroundStyle(CompanionChrome.ink)
                .frame(width: 26, height: 26)
                .background(CompanionChrome.cloud, in: Circle())
            Text(title)
                .font(CompanionChrome.font(.body, weight: .medium))
                .foregroundStyle(CompanionChrome.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
