import SwiftUI
import UIKit

struct InstructionsSection: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        CompanionScreen(title: "Enable") {
            CompanionCard {
                VStack(alignment: .leading, spacing: 16) {
                    CompanionSetupStep(number: 1, title: "Open Settings, then General")
                    CompanionSetupStep(number: 2, title: "Keyboard, then Keyboards")
                    CompanionSetupStep(number: 3, title: "Add Soratype")
                    Label {
                        Text("Soratype stays on this iPhone. Nothing you type is uploaded.")
                    } icon: {
                        Image(systemName: "lock.shield")
                    }
                    .font(CompanionChrome.font(.footnote))
                    .foregroundStyle(CompanionChrome.haze)
                    Button("Open Settings", action: openSettings)
                        .buttonStyle(.seal)
                }
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
