import SwiftUI

struct CompanionHiddenWordRow: View {
    let word: String
    let allow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(word)
                .font(CompanionChrome.font(.body, weight: .semibold))
                .foregroundStyle(CompanionChrome.ink)
            Spacer(minLength: 8)
            Button("Allow", action: allow)
                .font(CompanionChrome.font(.body, weight: .semibold))
                .foregroundStyle(CompanionChrome.seal)
        }
        .padding(.vertical, 2)
    }
}
