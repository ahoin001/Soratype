import SwiftUI
import SoratypeEngine

struct CompanionView: View {
    @State private var settings = SettingsStore().load()
    @State private var status = LexiconInstaller.current()
    @State private var saveNote: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    InstructionsSection()
                    LexiconSection(status: status) {
                        status = LexiconInstaller.rebuild()
                    }
                    TypingFlagsSection(settings: $settings, saveNote: saveNote)
                }
                .padding(20)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(CompanionChrome.paper)
            .navigationTitle("Soratype")
            .font(.system(.body, design: .rounded))
        }
        .onChange(of: settings) { _, updated in
            do {
                try SettingsStore().save(updated)
                saveNote = nil
            } catch {
                saveNote = "These switches could not be saved for the keyboard."
            }
        }
    }
}
