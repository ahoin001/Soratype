import SwiftUI

/// Air, with two still apricot glows. Drawn once into a single layer.
struct CompanionBackground: View {
    var body: some View {
        CompanionChrome.background
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(CompanionChrome.seal.opacity(0.20))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: 120, y: -140)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(CompanionChrome.seal.opacity(0.10))
                    .frame(width: 280, height: 280)
                    .blur(radius: 90)
                    .offset(x: -120, y: 120)
            }
            .drawingGroup()
            .ignoresSafeArea()
    }
}

extension View {
    func companionScreen() -> some View {
        background { CompanionBackground() }
    }
}
