import SwiftUI

struct AuthenticatedAccountView: View {
    let session: AuthSessionSnapshot
    let profile: MarketplaceProfile
    @Bindable var authenticationStore: AuthenticationStore

    var body: some View {
        ZStack {
            DesignTokens.Colors.appBackground
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                    BeckonPageTitle("Account")

                    BeckonAccountIdentityHeader(
                        displayName: profile.displayName,
                        detailText: emailSummary ?? profile.role.accountRoleLabel,
                        roleTitle: profile.role.accountRoleLabel,
                        roleAccent: profile.role.settingsAccent
                    ) {
                        BeckonDefaultProfileAvatar(
                            tone: profile.role.defaultAvatarTone,
                            symbolSize: 30
                        )
                        .clipShape(DesignTokens.Shapes.circular)
                        .accessibilityHidden(true)
                    }

                    BeckonSection("Support") {
                        AccountReleaseLinksSection(accent: profile.role.settingsAccent)
                    }

                    if let errorMessage = authenticationStore.errorMessage {
                        BeckonErrorBanner(
                            title: "Account action failed",
                            message: errorMessage
                        )
                        .accessibilityIdentifier("auth.error")
                    }

                    #if DEBUG
                    BeckonSection("Development") {
                        BeckonGroupedSurface {
                            BeckonSettingsNavigationRow(
                                title: "Debug console",
                                summary: "Runtime events and diagnostics",
                                systemImage: "ladybug",
                                accent: profile.role.settingsAccent
                            ) {
                                DebugPanelView(
                                    diagnostics: DebugDiagnostics.current(
                                        session: session,
                                        profile: profile
                                    )
                                )
                            }
                            .accessibilityIdentifier("account.debug-console")
                        }
                    }
                    #endif

                    BeckonSection("Account access") {
                        AccountDangerActions(
                            authenticationStore: authenticationStore
                        )
                    }
                }
                .beckonPageInsets()
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

struct AccountReleaseLinksSection: View {
    var accent: BeckonRoleAccent = .neutral

    private let dividerLeadingInset =
        DesignTokens.Layout.rowHorizontalInset
        + DesignTokens.Metrics.settingsIconSlot
        + DesignTokens.Spacing.md

    var body: some View {
        BeckonGroupedSurface {
            VStack(spacing: 0) {
                releaseLinkRow(
                    title: "Privacy policy",
                    systemImage: "hand.raised",
                    destination: AppReleaseLinks.privacyPolicy,
                    accessibilityIdentifier: "account.privacy-policy"
                )

                BeckonGroupedDivider(leadingInset: dividerLeadingInset)

                releaseLinkRow(
                    title: "Support",
                    systemImage: "questionmark.circle",
                    destination: AppReleaseLinks.support,
                    accessibilityIdentifier: "account.support"
                )
            }
        }
    }

    private func releaseLinkRow(
        title: String,
        systemImage: String,
        destination: URL,
        accessibilityIdentifier: String
    ) -> some View {
        Link(destination: destination) {
            BeckonSettingsRowLabel(
                title: title,
                systemImage: systemImage,
                accent: accent,
                trailingSystemImage: "arrow.up.right"
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct AccountDangerActions: View {
    @Bindable var authenticationStore: AuthenticationStore
    @State private var showsDeletionWarning = false
    @State private var showsFinalDeletionConfirmation = false
    @State private var activeAction: AccountDangerAction?

    var body: some View {
        BeckonCard {
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
            : "Sign out"
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
                        .tint(DesignTokens.Colors.statusErrorText)
                } else {
                    Image(systemName: systemImage)
                        .font(DesignTokens.Typography.action)
                        .foregroundStyle(DesignTokens.Colors.statusErrorText)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.statusErrorText)

                Spacer(minLength: 0)
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(BeckonDestructiveButtonStyle())
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
    var settingsAccent: BeckonRoleAccent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var accountRoleLabel: String {
        switch self {
        case .customer:
            "Pet Owner"
        case .groomer:
            "Groomer"
        }
    }

    var defaultAvatarTone: BeckonDefaultProfileAvatarTone {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }
}
