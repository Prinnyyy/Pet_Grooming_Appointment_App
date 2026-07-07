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

                    AccountDangerActions(
                        authenticationStore: authenticationStore
                    )
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

struct AccountDangerActions: View {
    @Bindable var authenticationStore: AuthenticationStore
    @State private var showsDeletionWarning = false
    @State private var showsFinalDeletionConfirmation = false
    @State private var activeAction: AccountDangerAction?

    var body: some View {
        GroomlyCard {
            VStack(spacing: DesignTokens.Spacing.md) {
                accountActionButton(
                    title: deleteAccountTitle,
                    systemImage: "trash",
                    accessibilityIdentifier: "auth.delete-account"
                ) {
                    showsDeletionWarning = true
                }

                Divider()

                accountActionButton(
                    title: signOutTitle,
                    systemImage: "rectangle.portrait.and.arrow.right",
                    accessibilityIdentifier: "auth.sign-out"
                ) {
                    signOut()
                }
            }
        }
        .confirmationDialog(
            "Delete Account?",
            isPresented: $showsDeletionWarning,
            titleVisibility: .visible
        ) {
            Button("Continue", role: .destructive) {
                showsFinalDeletionConfirmation = true
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This will remove your profile details, cancel active appointments, and sign you out."
            )
        }
        .alert(
            "Delete Account Permanently?",
            isPresented: $showsFinalDeletionConfirmation
        ) {
            Button("Delete Account", role: .destructive) {
                deleteAccount()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This action cannot be undone. Your account data will be anonymized and the sign-in user will be deleted."
            )
        }
    }

    private var deleteAccountTitle: String {
        activeAction == .deleteAccount && authenticationStore.isSubmitting
            ? "Deleting Account..."
            : "Delete Account"
    }

    private var signOutTitle: String {
        activeAction == .signOut && authenticationStore.isSubmitting
            ? "Signing Out..."
            : "Sign Out"
    }

    private func accountActionButton(
        title: String,
        systemImage: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: .destructive, action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if authenticationStore.isSubmitting
                    && (
                        accessibilityIdentifier == "auth.delete-account"
                        && activeAction == .deleteAccount
                        || accessibilityIdentifier == "auth.sign-out"
                        && activeAction == .signOut
                    )
                {
                    ProgressView()
                        .tint(DesignTokens.Colors.error)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.error)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.error)

                Spacer(minLength: 0)
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(authenticationStore.isSubmitting)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func signOut() {
        activeAction = .signOut
        Task {
            await authenticationStore.signOut()
            activeAction = nil
        }
    }

    private func deleteAccount() {
        activeAction = .deleteAccount
        Task {
            await authenticationStore.deleteAccount()
            activeAction = nil
        }
    }
}

private enum AccountDangerAction {
    case signOut
    case deleteAccount
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
