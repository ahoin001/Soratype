import SwiftUI

struct CompanionToggleRow: View {
    let systemImage: String
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .center, spacing: 14) {
                CompanionIcon(systemName: systemImage, size: 34)
                CompanionRowText(title: title, detail: detail)
            }
        }
        .tint(CompanionChrome.seal)
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}
