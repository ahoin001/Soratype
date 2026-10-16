import SwiftUI

private enum WordListFilter: String, CaseIterable, Identifiable {
    case learned = "Learned"
    case hidden = "Hidden"
    case forgotten = "Forgotten"

    var id: String { rawValue }
}

struct LexiconSection: View {
    let status: LexiconStatus
    let learned: [String]
    let blocked: [String]
    let forgotten: [String]
    let rebuild: () -> Void
    let forget: (String) -> Void
    let allow: (String) -> Void
    let resetLearning: () -> Void

    @State private var confirmingReset = false
    @State private var filter = WordListFilter.learned
    @State private var query = ""

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
                WordListFilterBar(filter: $filter)
                TextField("Filter these words", text: $query)
                    .font(CompanionChrome.font(.body))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(CompanionChrome.cloud, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                if visibleWords.isEmpty {
                    Text(emptyLine)
                        .font(CompanionChrome.font(.subheadline))
                        .foregroundStyle(CompanionChrome.haze)
                } else {
                    ForEach(visibleWords, id: \.self) { word in
                        CompanionHiddenWordRow(word: word, actionTitle: rowAction) {
                            switch filter {
                            case .learned:
                                forget(word)
                            case .hidden, .forgotten:
                                allow(word)
                            }
                        }
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
            Text("Learned, hidden, and forgotten words on this iPhone are cleared.")
        }
    }

    private var learnedLine: String {
        switch learned.count {
        case 0: "Nothing learned from your typing yet."
        case 1: "1 word learned from your typing."
        default: "\(learned.count.formatted()) words learned from your typing."
        }
    }

    private var rowAction: String {
        filter == .learned ? "Forget" : "Allow"
    }

    private var sourceWords: [String] {
        switch filter {
        case .learned: learned
        case .hidden: blocked
        case .forgotten: forgotten
        }
    }

    private var visibleWords: [String] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sorted = sourceWords.sorted()
        guard !needle.isEmpty else { return sorted }
        return sorted.filter { $0.lowercased().contains(needle) }
    }

    private var emptyLine: String {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !needle.isEmpty { return "No words match." }
        switch filter {
        case .learned: return "Nothing learned from your typing yet."
        case .hidden: return "No hidden words."
        case .forgotten: return "No forgotten words."
        }
    }
}

private struct WordListFilterBar: View {
    @Binding var filter: WordListFilter

    var body: some View {
        HStack(spacing: 8) {
            ForEach(WordListFilter.allCases) { item in
                Button {
                    filter = item
                } label: {
                    Text(item.rawValue)
                        .font(CompanionChrome.font(.subheadline, weight: .semibold))
                        .foregroundStyle(filter == item ? CompanionChrome.porcelain : CompanionChrome.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            filter == item ? CompanionChrome.seal : CompanionChrome.cloud,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
