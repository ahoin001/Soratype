import SwiftUI

struct CompanionDivider: View {
    var body: some View {
        Rectangle()
            .fill(CompanionChrome.haze.opacity(0.15))
            .frame(height: 1)
            .padding(.leading, 48)
    }
}
