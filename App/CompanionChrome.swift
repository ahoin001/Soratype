import SwiftUI

enum CompanionChrome {
    static let paper = Color(red: 0.957, green: 0.945, blue: 0.925)
    static let ink = Color(red: 0.173, green: 0.165, blue: 0.157)
}

extension View {
    func companionCard() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
