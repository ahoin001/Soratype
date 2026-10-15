import SwiftUI

struct LexiconSection: View {
    let status: LexiconStatus
    let rebuild: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("English")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text("\(status.wordCount) words · \(status.byteCount) bytes")
                .monospacedDigit()
            Text(status.note)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Rebuild word list", action: rebuild)
                .buttonStyle(.borderedProminent)
                .tint(CompanionChrome.ink)
        }
        .companionCard()
    }
}
