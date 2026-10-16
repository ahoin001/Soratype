import SwiftUI

struct CompanionHiddenWordRow: View {
    let word: String
    var actionTitle: String = "Allow"
    let perform: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(word)
                .font(CompanionChrome.font(.body, weight: .semibold))
                .foregroundStyle(CompanionChrome.ink)
            Spacer(minLength: 8)
            Button(actionTitle, action: perform)
                .font(CompanionChrome.font(.body, weight: .semibold))
                .foregroundStyle(CompanionChrome.seal)
        }
        .padding(.vertical, 2)
    }
}
