import SwiftUI

struct AuthenticationBootstrapView: View {
    let state: AuthenticationBootstrapState

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignTokens.Spacing.standard) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(iconStyle)

                Text("Pet Groomer Marketplace")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.Colors.primaryText)

                Text(statusMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)

                if case let .configurationError(message) = state {
                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("auth.bootstrap.configuration-error")
                }
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
            .accentColor
        case .configurationError:
            .red
        }
    }

    private var statusMessage: String {
        switch state {
        case .ready:
            "Authentication infrastructure is ready. Sign-in arrives in T-006."
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
