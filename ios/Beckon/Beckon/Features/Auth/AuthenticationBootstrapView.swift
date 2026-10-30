import SwiftUI

struct AuthenticationBootstrapView: View {
    let state: AuthenticationBootstrapState

    var body: some View {
        switch state {
        case .ready: LaunchWaitingView()
        case .configurationError:
            configurationErrorContent.preference(key: LaunchReadyKey.self, value: true)
        }
    }

    private var configurationErrorContent: some View {
        ZStack {
            DesignTokens.Colors.appBackground
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
                        Text("Beckon")
                            .font(DesignTokens.Typography.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text(statusMessage)
                            .font(DesignTokens.Typography.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                }

                if case let .configurationError(message) = state {
                    BeckonErrorBanner(
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
            DesignTokens.Colors.customerDeep
        case .configurationError:
            DesignTokens.Colors.statusErrorText
        }
    }

    private var iconBackground: Color {
        switch state {
        case .ready:
            DesignTokens.Colors.customerTint
        case .configurationError:
            DesignTokens.Colors.statusErrorFill
        }
    }

    private var statusMessage: String {
        switch state {
        case .ready:
            "Pet groomers at your beck and call."
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
