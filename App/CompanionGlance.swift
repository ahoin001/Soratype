import SwiftUI

struct CompanionGlance: View {
    let wordCount: Int
    let learnedCount: Int
    let hiddenCount: Int

    var body: some View {
        CompanionCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    CompanionIcon(systemName: "books.vertical", size: 30)
                    Text("On this iPhone")
                        .font(CompanionChrome.font(.headline, weight: .bold))
                        .foregroundStyle(CompanionChrome.ink)
                    Spacer(minLength: 0)
                }
                HStack(alignment: .top, spacing: 8) {
                    CompanionGlanceStat(value: wordCount, label: "dictionary words")
                    CompanionGlanceStat(value: learnedCount, label: "learned")
                    CompanionGlanceStat(value: hiddenCount, label: "hidden")
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
