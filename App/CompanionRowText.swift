import SwiftUI

struct CompanionRowText: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(CompanionChrome.font(.body, weight: .semibold))
                .foregroundStyle(CompanionChrome.ink)
            if let detail {
                Text(detail)
                    .font(CompanionChrome.font(.footnote))
                    .foregroundStyle(CompanionChrome.haze)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
