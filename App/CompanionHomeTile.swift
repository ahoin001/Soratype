import SwiftUI

struct CompanionHomeTile: View {
    let destination: CompanionDestination
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        NavigationLink(value: destination) {
            CompanionCard(padding: 16, cornerRadius: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    CompanionIcon(systemName: systemImage)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(CompanionChrome.font(.headline, weight: .bold))
                            .foregroundStyle(CompanionChrome.ink)
                        Text(subtitle)
                            .font(CompanionChrome.font(.footnote, weight: .medium))
                            .foregroundStyle(CompanionChrome.haze)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(CompanionPressStyle())
    }
}
