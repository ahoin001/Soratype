import SwiftUI

struct CompanionGlanceStat: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(CompanionChrome.font(.title2, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(CompanionChrome.seal)
                .contentTransition(.numericText(value: Double(value)))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(CompanionChrome.font(.caption, weight: .medium))
                .foregroundStyle(CompanionChrome.haze)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
