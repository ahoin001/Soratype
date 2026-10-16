import SwiftUI

struct CompanionHomeLinks: View {
    let learnedLine: String

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: columns, spacing: 14) {
                CompanionHomeTile(
                    destination: .enable,
                    systemImage: "keyboard",
                    title: "Enable",
                    subtitle: "Add it in Settings"
                )
                CompanionHomeTile(
                    destination: .words,
                    systemImage: "text.book.closed",
                    title: "Words",
                    subtitle: learnedLine
                )
            }
            NavigationLink(value: CompanionDestination.typing) {
                CompanionCard(padding: 16, cornerRadius: 24) {
                    CompanionLinkRow(
                        systemImage: "slider.horizontal.3",
                        title: "Typing",
                        detail: "Space, delete, and the pause between thumbs"
                    )
                }
            }
            .buttonStyle(CompanionPressStyle())
        }
    }
}
