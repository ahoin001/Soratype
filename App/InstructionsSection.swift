import SwiftUI

struct InstructionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enable Soratype")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("Open Settings, then General, then Keyboard, then Keyboards, and add Soratype. Full Access lets the keyboard read the word list and the five switches below. Those files stay on this iPhone.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
