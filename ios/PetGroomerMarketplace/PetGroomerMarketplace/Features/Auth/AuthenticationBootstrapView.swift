import SwiftUI

struct AuthenticationBootstrapView: View {
    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignTokens.Spacing.standard) {
                Image(systemName: "scissors")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)

                Text("Pet Groomer Marketplace")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.Colors.primaryText)

                Text("Authentication is not connected yet.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }
            .padding(DesignTokens.Spacing.large)
            .background(DesignTokens.Colors.surface)
            .clipShape(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
            )
            .padding(DesignTokens.Spacing.standard)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("auth.bootstrap")
        }
    }
}
