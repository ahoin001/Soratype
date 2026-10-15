import SwiftUI
import SoratypeEngine

struct TypingFlagsSection: View {
    @Binding var settings: EngineSettings
    var saveNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Typing")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Toggle("Allow a short gap between thumbs", isOn: $settings.handoffGraceEnabled)
            Toggle("Backspace removes the whole swipe", isOn: swipeRemoved)
            Toggle("Double space types a period", isOn: $settings.doubleSpacePeriod)
            Toggle("Finish the other thumb before space or delete", isOn: $settings.queueBoundaryUntilLift)
            DisclosureGroup("Advanced") {
                Stepper(value: $settings.handoffGraceMilliseconds, in: 40...150, step: 5) {
                    Text("Gap \(settings.handoffGraceMilliseconds) ms")
                        .monospacedDigit()
                }
                .disabled(!settings.handoffGraceEnabled)
            }
            .foregroundStyle(CompanionChrome.haze)
            if let saveNote {
                Text(saveNote)
                    .font(.footnote)
                    .foregroundStyle(CompanionChrome.caution)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .companionCard()
    }

    private var swipeRemoved: Binding<Bool> {
        Binding(
            get: { settings.backspaceMode == .removeWordAndSpace },
            set: { settings.backspaceMode = $0 ? .removeWordAndSpace : .reopenAimedLetters }
        )
    }
}
