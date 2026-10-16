import SwiftUI

enum CompanionMotion {
    static let gentle = Animation.spring(response: 0.35, dampingFraction: 1)
    static let press = Animation.spring(response: 0.25, dampingFraction: 0.7)
}
