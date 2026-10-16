import SwiftUI

struct CompanionSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 10) {
            CompanionSectionHeader(title: title)
            CompanionCard(padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
            }
        }
    }
}
