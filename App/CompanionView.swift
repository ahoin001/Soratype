import SwiftUI
import SoratypeEngine

struct CompanionView: View {
    @State private var settings = SettingsStore().load()
    @State private var status = LexiconInstaller.current()
    @State private var saveNote: String?
    @State private var learned: [String] = []
    @State private var blocked: [String] = []
    @State private var forgotten: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    CompanionHomeHeader()
                    CompanionGlance(
                        wordCount: status.wordCount,
                        learnedCount: learned.count,
                        hiddenCount: blocked.count
                    )
                    CompanionHomeLinks(learnedLine: learnedLine)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .companionScreen()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CompanionDestination.self) { destination in
                switch destination {
                case .enable:
                    InstructionsSection()
                case .words:
                    LexiconSection(
                        status: status,
                        learned: learned,
                        blocked: blocked,
                        forgotten: forgotten,
                        rebuild: { status = LexiconInstaller.rebuild() },
                        forget: forgetWord,
                        allow: allowWord,
                        resetLearning: resetLearning
                    )
                case .typing:
                    TypingFlagsSection(settings: $settings, saveNote: saveNote)
                }
            }
        }
        .tint(CompanionChrome.seal)
        .preferredColorScheme(.light)
        .onChange(of: settings) { _, updated in
            do {
                try SettingsStore().save(updated)
                saveNote = nil
            } catch {
                saveNote = "These switches could not be saved for the keyboard."
            }
        }
        .onAppear(perform: refreshLearnedCount)
    }

    private var learnedLine: String {
        switch learned.count {
        case 0: "Nothing learned yet"
        case 1: "1 word learned"
        default: "\(learned.count.formatted()) words learned"
        }
    }

    private func refreshLearnedCount() {
        let memory = SharedFiles.memoryURL().map { MemoryStore(url: $0).load() } ?? .empty
        learned = memory.personal.keys.sorted()
        blocked = memory.blocklist
        forgotten = memory.forgotten
    }

    private func allowWord(_ word: String) {
        guard let url = SharedFiles.memoryURL() else { return }
        var memory = MemoryStore(url: url).load()
        memory.allow(word)
        try? MemoryStore(url: url).save(memory)
        refreshLearnedCount()
    }

    private func forgetWord(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = SharedFiles.memoryURL() else { return }
        var memory = MemoryStore(url: url).load()
        memory.forget(trimmed)
        try? MemoryStore(url: url).save(memory)
        refreshLearnedCount()
    }

    private func resetLearning() {
        guard let url = SharedFiles.memoryURL() else { return }
        try? MemoryStore(url: url).save(.empty)
        refreshLearnedCount()
    }
}
