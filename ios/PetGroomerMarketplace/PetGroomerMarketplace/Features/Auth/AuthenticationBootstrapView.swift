import SwiftUI

struct AuthenticationBootstrapView: View {
    let state: AuthenticationBootstrapState

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignTokens.Spacing.xl) {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: systemImage)
                        .font(DesignTokens.Typography.largeTitle.weight(.semibold))
                        .foregroundStyle(iconStyle)
                        .frame(
                            width: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl + DesignTokens.Spacing.lg,
                            height: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl + DesignTokens.Spacing.lg
                        )
                        .background(iconBackground)
                        .clipShape(DesignTokens.Shapes.circular)
                        .accessibilityHidden(true)

                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Text("Groomly")
                            .font(DesignTokens.Typography.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(DesignTokens.Colors.primaryText)

                        Text(statusMessage)
                            .font(DesignTokens.Typography.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(DesignTokens.Colors.secondaryText)
                    }
                }

                if case let .configurationError(message) = state {
                    GroomlyErrorBanner(
                        title: "Configuration unavailable",
                        message: message
                    )
                    .accessibilityIdentifier("auth.bootstrap.configuration-error")
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("auth.bootstrap")
        }
    }

    private var systemImage: String {
        switch state {
        case .ready:
            "scissors"
        case .configurationError:
            "exclamationmark.triangle"
        }
    }

    private var iconStyle: Color {
        switch state {
        case .ready:
            DesignTokens.Colors.customerPrimaryDark
        case .configurationError:
            DesignTokens.Colors.error
        }
    }

    private var iconBackground: Color {
        switch state {
        case .ready:
            DesignTokens.Colors.customerPrimary.opacity(0.16)
        case .configurationError:
            DesignTokens.Colors.error.opacity(0.12)
        }
    }

    private var statusMessage: String {
        switch state {
        case .ready:
            "Find trusted independent groomers for your pet."
        case .configurationError:
            "Supabase configuration is unavailable."
        }
    }
}

#Preview("Configured") {
    AuthenticationBootstrapView(state: .ready)
}

#Preview("Missing configuration") {
    AuthenticationBootstrapView(
        state: .configurationError(message: "Missing required configuration value.")
    )
}
