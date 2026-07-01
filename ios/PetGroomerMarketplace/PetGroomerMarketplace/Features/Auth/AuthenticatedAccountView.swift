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
                    AccountTabTitle("Account")

                    GroomlyCard {
                        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
                            GroomlyDefaultProfileAvatar(
                                tone: profile.role.defaultAvatarTone,
                                symbolSize: 30
                            )
                                .frame(
                                    width: 72,
                                    height: 72
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text(profile.displayName)
                                    .font(DesignTokens.Typography.title)
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let emailSummary {
                                    Text(emailSummary)
                                        .font(DesignTokens.Typography.body)
                                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                                        .lineLimit(1)
                                }

                                GroomlyStatusChip(
                                    profile.role.accountRoleLabel,
                                    tone: profile.role.accountChipTone
                                )
                                .padding(.top, DesignTokens.Spacing.xs)
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
                        Label("Debug Console", systemImage: "ladybug")
                            .font(DesignTokens.Typography.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DesignTokens.Spacing.lg)
                            .background(DesignTokens.Colors.surfaceRaised)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: DesignTokens.CornerRadius.card,
                                    style: .continuous
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("account.debug-console")
                    #endif

                    Button(role: .destructive) {
                        Task {
                            await authenticationStore.signOut()
                        }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Spacer(minLength: 0)

                            if authenticationStore.isSubmitting {
                                ProgressView()
                                    .tint(DesignTokens.Colors.error)
                            }

                            Text(
                                authenticationStore.isSubmitting
                                    ? "Signing Out..."
                                    : "Sign Out"
                            )
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.error)

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, DesignTokens.Spacing.md)
                    }
                    .buttonStyle(.plain)
                    .disabled(authenticationStore.isSubmitting)
                    .accessibilityIdentifier("auth.sign-out")
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.xl + DesignTokens.Spacing.xl)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("account.authenticated")
    }

    private var emailSummary: String? {
        session.email
    }
}

struct AccountTabTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 36, weight: .bold))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DesignTokens.Spacing.sm)
    }
}

private extension UserRole {
    var accountRoleLabel: String {
        switch self {
        case .customer:
            "Pet Owner"
        case .groomer:
            "Groomer"
        }
    }

    var accountChipTone: GroomlyStatusChip.Tone {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var defaultAvatarTone: GroomlyDefaultProfileAvatarTone {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }
}
