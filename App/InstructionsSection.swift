import SwiftUI
import UIKit

struct InstructionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enable")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Open Settings")
                Text("2. General, then Keyboard, then Keyboards")
                Text("3. Add Soratype")
            }
            .foregroundStyle(CompanionChrome.haze)
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(SealButtonStyle())
        }
        .companionCard()
    }
}
