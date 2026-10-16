import SwiftUI

struct LexiconSection: View {
    let status: LexiconStatus
    let learnedCount: Int
    let blocked: [String]
    @Binding var forgetWord: String
    let rebuild: () -> Void
    let forget: () -> Void
    let allow: (String) -> Void
    let resetLearning: () -> Void

    @State private var confirmingReset = false

    var body: some View {
        CompanionScreen(title: "Words") {
            CompanionSection(title: "Dictionary") {
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.wordCount, format: .number)
                        .font(CompanionChrome.font(.title, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(CompanionChrome.seal)
                        .contentTransition(.numericText(value: Double(status.wordCount)))
                    Text("words on this iPhone")
                        .font(CompanionChrome.font(.subheadline, weight: .medium))
                        .foregroundStyle(CompanionChrome.haze)
                }
                Text(status.note)
                    .font(CompanionChrome.font(.subheadline))
                    .foregroundStyle(CompanionChrome.haze)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Rebuild word list", action: rebuild)
                    .font(CompanionChrome.font(.body, weight: .semibold))
                    .foregroundStyle(CompanionChrome.seal)
            }

            CompanionSection(title: "Yours") {
                Text(learnedLine)
                    .font(CompanionChrome.font(.body, weight: .semibold))
                    .foregroundStyle(CompanionChrome.ink)
                TextField("Word to forget", text: $forgetWord)
                    .font(CompanionChrome.font(.body))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(CompanionChrome.cloud, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Button("Forget this word", action: forget)
                    .buttonStyle(.seal)
                    .disabled(forgetWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !blocked.isEmpty {
                    CompanionDivider()
                    Text("Hidden words")
                        .font(CompanionChrome.font(.subheadline, weight: .semibold))
                        .foregroundStyle(CompanionChrome.haze)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(blocked, id: \.self) { word in
                        CompanionHiddenWordRow(word: word) { allow(word) }
                    }
                }
                CompanionDivider()
                Button("Reset learning", role: .destructive) {
                    confirmingReset = true
                }
                .font(CompanionChrome.font(.body, weight: .semibold))
                Text("Nothing leaves the phone.")
                    .font(CompanionChrome.font(.footnote))
                    .foregroundStyle(CompanionChrome.haze)
            }
        }
        .confirmationDialog(
            "Reset learning?",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset learning", role: .destructive, action: resetLearning)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Learned words and hidden spellings on this iPhone are cleared.")
        }
    }

    private var learnedLine: String {
        switch learnedCount {
        case 0: "Nothing learned from your typing yet."
        case 1: "1 word learned from your typing."
        default: "\(learnedCount.formatted()) words learned from your typing."
        }
    }
}
