import SwiftUI

struct AuthenticatedAccountView: View {
    let session: AuthSessionSnapshot
    let profile: MarketplaceProfile
    @Bindable var authenticationStore: AuthenticationStore

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    GroomlySectionHeader(
                        "Account",
                        subtitle: "Your active Groomly profile."
                    )

                    GroomlyCard {
                        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(DesignTokens.Typography.largeTitle)
                                .foregroundStyle(profile.role.accountAccentColor)
                                .frame(
                                    width: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl,
                                    height: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl
                                )
                                .background(profile.role.accountAccentBackground)
                                .clipShape(DesignTokens.Shapes.circular)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                Text(profile.displayName)
                                    .font(DesignTokens.Typography.title)
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    GroomlyStatusChip(
                                        profile.role.title,
                                        systemImage: profile.role.accountSystemImage,
                                        tone: profile.role.accountChipTone
                                    )

                                    if let maskedEmail {
                                        Text(maskedEmail)
                                            .font(DesignTokens.Typography.caption)
                                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    if let errorMessage = authenticationStore.errorMessage {
                        GroomlyErrorBanner(
                            title: "Account action failed",
                            message: errorMessage
                        )
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
                    }
                    .buttonStyle(GroomlySecondaryButtonStyle(accent: .neutral))
                    .accessibilityIdentifier("debug.panel.link")
                #endif

                    Button(role: .destructive) {
                        Task {
                            await authenticationStore.signOut()
                        }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            if authenticationStore.isSubmitting {
                                ProgressView()
                                    .tint(DesignTokens.Colors.textSecondary)
                            }

                            Text(
                                authenticationStore.isSubmitting
                                    ? "Signing out…"
                                    : "Sign Out"
                            )
                        }
                    }
                    .buttonStyle(GroomlySecondaryButtonStyle(accent: .neutral))
                    .disabled(authenticationStore.isSubmitting)
                    .accessibilityIdentifier("auth.sign-out")
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("account.authenticated")
    }

    private var maskedEmail: String? {
        guard let email = session.email else { return nil }
        return Self.maskedEmail(email)
    }

    private static func maskedEmail(_ email: String) -> String {
        let pieces = email.split(separator: "@", maxSplits: 1)
        guard pieces.count == 2 else {
            return "Email hidden"
        }

        let local = String(pieces[0])
        let domain = String(pieces[1]).lowercased()
        let prefix = local.first.map(String.init) ?? "•"
        return "\(prefix)•••@\(domain)"
    }
}

private extension UserRole {
    var accountChipTone: GroomlyStatusChip.Tone {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var accountAccentColor: Color {
        switch self {
        case .customer:
            DesignTokens.Colors.customerPrimaryDark
        case .groomer:
            DesignTokens.Colors.groomerAccentDark
        }
    }

    var accountAccentBackground: Color {
        switch self {
        case .customer:
            DesignTokens.Colors.customerPrimary.opacity(0.14)
        case .groomer:
            DesignTokens.Colors.groomerAccent.opacity(0.14)
        }
    }

    var accountSystemImage: String {
        switch self {
        case .customer:
            "pawprint.fill"
        case .groomer:
            "scissors"
        }
    }
}
