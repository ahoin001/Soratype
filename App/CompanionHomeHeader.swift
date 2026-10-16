import SwiftUI

struct CompanionHomeHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            CompanionMark(size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Soratype")
                    .font(CompanionChrome.font(.largeTitle, weight: .bold))
                    .foregroundStyle(CompanionChrome.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Words that follow your thumbs")
                    .font(CompanionChrome.font(.subheadline, weight: .medium))
                    .foregroundStyle(CompanionChrome.haze)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }
}
