import SwiftUI

enum DesignTokens {
    enum Colors {
        static let background = Color(uiColor: .systemGroupedBackground)
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
    }

    enum Spacing {
        static let standard: CGFloat = 16
        static let large: CGFloat = 24
    }

    enum CornerRadius {
        static let card: CGFloat = 16
    }
}
