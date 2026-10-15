import SwiftUI

struct LexiconSection: View {
    let status: LexiconStatus
    let learnedCount: Int
    @Binding var forgetWord: String
    let rebuild: () -> Void
    let forget: () -> Void
    let resetLearning: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Words")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text("\(status.wordCount.formatted()) words on this iPhone")
                .foregroundStyle(CompanionChrome.haze)
            Text(status.note)
                .foregroundStyle(CompanionChrome.haze)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(learnedCount.formatted()) words learned from your typing")
                .monospacedDigit()
            TextField("Word to forget", text: $forgetWord)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(CompanionChrome.air, in: .rect(cornerRadius: 12))
            Button("Forget this word", action: forget)
                .buttonStyle(SealButtonStyle())
                .disabled(forgetWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Rebuild word list", action: rebuild)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CompanionChrome.haze)
            Button("Reset learning", role: .destructive, action: resetLearning)
                .font(.system(.body, design: .rounded))
            Text("Nothing leaves the phone.")
                .font(.footnote)
                .foregroundStyle(CompanionChrome.haze)
        }
        .companionCard()
    }
}
