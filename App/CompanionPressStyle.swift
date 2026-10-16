import SwiftUI

/// A gentle squish for cards and rows. No color flash.
struct CompanionPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : CompanionMotion.press, value: configuration.isPressed)
    }
}
