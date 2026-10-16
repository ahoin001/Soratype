import SwiftUI
import SoratypeEngine

struct TypingFlagsSection: View {
    @Binding var settings: EngineSettings
    var saveNote: String?

    var body: some View {
        CompanionScreen(title: "Typing") {
            CompanionCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    CompanionToggleRow(
                        systemImage: "hand.raised.fingers.spread",
                        title: "A short gap between thumbs",
                        detail: "The second thumb can still join the word.",
                        isOn: $settings.handoffGraceEnabled
                    )
                    if settings.handoffGraceEnabled {
                        CompanionDivider()
                        Stepper(value: $settings.handoffGraceMilliseconds, in: 40...150, step: 5) {
                            CompanionRowText(
                                title: "Gap",
                                detail: "\(settings.handoffGraceMilliseconds) ms before the word settles"
                            )
                        }
                        .padding(.leading, 48)
                        .padding(.vertical, 4)
                    }
                    CompanionDivider()
                    CompanionToggleRow(
                        systemImage: "delete.left",
                        title: "Backspace removes the whole swipe",
                        detail: settings.backspaceMode == .removeWordAndSpace
                            ? "The first delete takes the swipe and its space."
                            : "The first delete reopens the letters you aimed.",
                        isOn: swipeRemoved
                    )
                    CompanionDivider()
                    CompanionToggleRow(
                        systemImage: "circle.fill",
                        title: "Double space types a period",
                        detail: "The second space, tapped quickly, ends the sentence.",
                        isOn: $settings.doubleSpacePeriod
                    )
                    CompanionDivider()
                    CompanionToggleRow(
                        systemImage: "arrow.left.and.right",
                        title: "Wait for the other thumb",
                        detail: "Space and delete hold until that thumb lifts.",
                        isOn: $settings.queueBoundaryUntilLift
                    )
                }
                .animation(CompanionMotion.gentle, value: settings.handoffGraceEnabled)
            }
            if let saveNote {
                Text(saveNote)
                    .font(CompanionChrome.font(.footnote, weight: .medium))
                    .foregroundStyle(CompanionChrome.caution)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
        }
    }

    private var swipeRemoved: Binding<Bool> {
        Binding(
            get: { settings.backspaceMode == .removeWordAndSpace },
            set: { settings.backspaceMode = $0 ? .removeWordAndSpace : .reopenAimedLetters }
        )
    }
}
