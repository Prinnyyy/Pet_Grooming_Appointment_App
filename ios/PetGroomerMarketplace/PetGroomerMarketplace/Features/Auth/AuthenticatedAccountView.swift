import SwiftUI

struct AuthenticatedAccountView: View {
    let session: AuthSessionSnapshot
    let profile: MarketplaceProfile
    @Bindable var authenticationStore: AuthenticationStore

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignTokens.Spacing.standard) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text(profile.displayName)
                    .font(.title2.bold())

                Text(profile.role.title)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)

                if let email = session.email {
                    Text(email)
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.Colors.secondaryText)
                }

                if let errorMessage = authenticationStore.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("auth.error")
                }

                #if DEBUG
                NavigationLink {
                    DebugPanelView(
                        diagnostics: DebugDiagnostics.current(
                            session: session,
                            profile: profile
                        )
                    )
                } label: {
                    Label("Debug Panel", systemImage: "ladybug")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("debug.panel.link")
                #endif

                Button(role: .destructive) {
                    Task {
                        await authenticationStore.signOut()
                    }
                } label: {
                    HStack {
                        if authenticationStore.isSubmitting {
                            ProgressView()
                        }
                        Text(
                            authenticationStore.isSubmitting
                                ? "Signing out…"
                                : "Sign Out"
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(authenticationStore.isSubmitting)
                .accessibilityIdentifier("auth.sign-out")
            }
            .padding(DesignTokens.Spacing.large)
            .background(DesignTokens.Colors.surface)
            .clipShape(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
            )
            .padding(DesignTokens.Spacing.standard)
        }
        .navigationTitle("Account")
        .accessibilityIdentifier("account.authenticated")
    }
}
