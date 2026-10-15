import SwiftUI
import SoratypeEngine

struct TypingFlagsSection: View {
    @Binding var settings: EngineSettings
    var saveNote: String?

    var body: some View {
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
            if let saveNote {
                Text(saveNote)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .companionCard()
    }
}
