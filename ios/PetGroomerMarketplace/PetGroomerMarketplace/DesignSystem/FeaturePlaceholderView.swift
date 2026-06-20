import SwiftUI

struct FeaturePlaceholderView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignTokens.Spacing.standard) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(.tint)

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(DesignTokens.Colors.primaryText)

                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }
            .padding(DesignTokens.Spacing.large)
            .background(DesignTokens.Colors.surface)
            .clipShape(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
            )
            .padding(DesignTokens.Spacing.standard)
        }
        .navigationTitle(title)
    }
}
