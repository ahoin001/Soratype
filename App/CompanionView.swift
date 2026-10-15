import SwiftUI
import SoratypeEngine

struct CompanionView: View {
    @State private var settings = SettingsStore().load()
    @State private var status = LexiconInstaller.current()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    instructions
                    lexicon
                    flags
                }
                .padding(20)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(paper)
            .navigationTitle("Soratype")
            .font(.system(.body, design: .rounded))
        }
        .onChange(of: settings) { _, updated in
            SettingsStore().save(updated)
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enable Soratype")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("Open Settings, then General, then Keyboard, then Keyboards, and add Soratype. Full Access lets the keyboard read the word list and the five switches below. Those files stay on this iPhone.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var lexicon: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("English")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text("\(status.wordCount) words · \(status.byteCount) bytes")
                .monospacedDigit()
            Text(status.note)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Rebuild word list") {
                status = LexiconInstaller.rebuild()
            }
            .buttonStyle(.borderedProminent)
            .tint(ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var flags: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Typing")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Toggle("Hand-off grace", isOn: $settings.handoffGraceEnabled)
            Stepper(value: $settings.handoffGraceMilliseconds, in: 40...150, step: 5) {
                Text("Grace \(settings.handoffGraceMilliseconds) ms")
            }
            .disabled(!settings.handoffGraceEnabled)
            Picker("Finished swipe", selection: $settings.backspaceMode) {
                Text("Remove word").tag(BackspaceMode.removeWordAndSpace)
                Text("Reopen letters").tag(BackspaceMode.reopenAimedLetters)
            }
            Toggle("Hold space and delete until lift", isOn: $settings.queueBoundaryUntilLift)
            Toggle("Double space inserts a period", isOn: $settings.doubleSpacePeriod)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var paper: Color { Color(red: 0.957, green: 0.945, blue: 0.925) }
    private var ink: Color { Color(red: 0.173, green: 0.165, blue: 0.157) }
}
