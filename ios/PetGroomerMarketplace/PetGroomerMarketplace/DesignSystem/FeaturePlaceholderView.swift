import SwiftUI

struct FeaturePlaceholderView: View {
    enum Accent {
        case customer
        case groomer

        var emptyStateAccent: GroomlyEmptyState<EmptyView>.Accent {
            switch self {
            case .customer:
                .customer
            case .groomer:
                .groomer
            }
        }
    }

    let title: String
    let message: String
    let systemImage: String
    let accent: Accent

    init(
        title: String,
        message: String,
        systemImage: String,
        accent: Accent = .customer
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.accent = accent
    }

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            GroomlyEmptyState(
                title: title,
                message: message,
                systemImage: systemImage,
                accent: accent.emptyStateAccent
            )
            .padding(DesignTokens.Spacing.standard)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
