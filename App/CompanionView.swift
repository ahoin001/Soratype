import SwiftUI
import SoratypeEngine

struct CompanionView: View {
    @State private var settings = SettingsStore().load()
    @State private var status = LexiconInstaller.current()
    @State private var saveNote: String?
    @State private var learnedCount = 0
    @State private var forgetWord = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    InstructionsSection()
                    LexiconSection(
                        status: status,
                        learnedCount: learnedCount,
                        forgetWord: $forgetWord,
                        rebuild: { status = LexiconInstaller.rebuild() },
                        forget: forgetLearnedWord,
                        resetLearning: resetLearning
                    )
                    TypingFlagsSection(settings: $settings, saveNote: saveNote)
                }
                .padding(20)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(CompanionChrome.air.ignoresSafeArea())
            .navigationTitle("Soratype")
            .toolbarBackground(CompanionChrome.air, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(CompanionChrome.ink)
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

    private func refreshLearnedCount() {
        learnedCount = SharedFiles.memoryURL().map { MemoryStore(url: $0).load().personal.count } ?? 0
    }

    private func forgetLearnedWord() {
        let word = forgetWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, let url = SharedFiles.memoryURL() else { return }
        var memory = MemoryStore(url: url).load()
        memory.forget(word)
        try? MemoryStore(url: url).save(memory)
        forgetWord = ""
        refreshLearnedCount()
    }

    private func resetLearning() {
        guard let url = SharedFiles.memoryURL() else { return }
        try? MemoryStore(url: url).save(.empty)
        refreshLearnedCount()
    }
}
