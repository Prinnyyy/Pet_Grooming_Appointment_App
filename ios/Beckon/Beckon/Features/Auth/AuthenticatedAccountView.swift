import SwiftUI

struct AuthenticatedAccountView: View {
    let session: AuthSessionSnapshot
    let profile: MarketplaceProfile
    @Bindable var authenticationStore: AuthenticationStore

    var body: some View {
        ZStack {
            BeckonExpressiveBackdrop()

            ScrollView {
                BeckonCascade(spacing: DesignTokens.Layout.sectionSpacing) {
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

                    BeckonSection("Help") {
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
        .environment(\.beckonCustomerDesign, true)
        .beckonEntranceRhythm(.list)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("account.authenticated")
    }

    private var emailSummary: String? {
        session.email
    }
}

struct AccountReleaseLinksSection: View {
    @Environment(\.openURL) private var openURL
    var accent: BeckonRoleAccent = .neutral

    private let dividerLeadingInset =
        DesignTokens.Layout.rowHorizontalInset
        + DesignTokens.Metrics.settingsIconSlot
        + DesignTokens.Spacing.md

    var body: some View {
        BeckonGroupedSurface {
            VStack(spacing: 0) {
                releaseLinkRow(
                    title: "Support",
                    systemImage: "questionmark.circle",
                    destination: AppReleaseLinks.support,
                    accessibilityIdentifier: "account.support"
                )

                BeckonGroupedDivider(leadingInset: dividerLeadingInset)

                releaseLinkRow(
                    title: "Privacy policy",
                    systemImage: "hand.raised",
                    destination: AppReleaseLinks.privacyPolicy,
                    accessibilityIdentifier: "account.privacy-policy"
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
        Button { openURL(destination) } label: {
            BeckonSettingsRowLabel(
                title: title,
                systemImage: systemImage,
                accent: accent,
                trailingSystemImage: "arrow.up.right"
            )
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct AccountDangerActions: View {
    @Bindable var authenticationStore: AuthenticationStore
    @State private var showsDeletionWarning = false
    @State private var showsFinalDeletionConfirmation = false
    @State private var activeAction: AccountDangerAction?

    var body: some View {
        // Signing out is routine and safe: a normal button. Deleting the account is rare and cannot be undone: a quiet red
        // action on its own, below, so the two are never one tap apart in the same style.
        VStack(spacing: DesignTokens.Spacing.sm) {
            signOutButton
            deleteAccountButton
        }
        // Two questions on purpose: the first says what goes, the second is the point of no return.
        .designAlertDialog(isPresented: $showsDeletionWarning) {
            .destructive(title: "Delete Account?",
                message: "This will remove your profile details, cancel active appointments, and sign you out.",
                systemImage: "trash.fill", keepTitle: "Cancel", confirmTitle: "Continue", confirmSystemImage: "arrow.right") {
                showsFinalDeletionConfirmation = true
            }
        }
        .designAlertDialog(isPresented: $showsFinalDeletionConfirmation) {
            .destructive(title: "Delete Account Permanently?",
                message: "This action cannot be undone. Your account data will be anonymized and the sign-in user will be deleted.",
                systemImage: "trash.fill", keepTitle: "Cancel", confirmTitle: "Delete Account") {
                deleteAccount()
            }
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

    private var isSigningOut: Bool {
        authenticationStore.isSubmitting && activeAction == .signOut
    }

    private var isDeleting: Bool {
        authenticationStore.isSubmitting && activeAction == .deleteAccount
    }

    private var signOutButton: some View {
        Button {
            signOut()
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isSigningOut {
                    ProgressView()
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .accessibilityHidden(true)
                }
                Text(signOutTitle)
            }
            .font(DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
        .disabled(authenticationStore.isSubmitting)
        .accessibilityIdentifier("auth.sign-out")
    }

    private var deleteAccountButton: some View {
        Button(role: .destructive) {
            showsDeletionWarning = true
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isDeleting {
                    ProgressView()
                        .tint(DesignTokens.Colors.statusErrorText)
                } else {
                    Image(systemName: "trash")
                        .accessibilityHidden(true)
                }
                Text(deleteAccountTitle)
            }
            .font(DesignTokens.Typography.Expressive.supporting)
            .foregroundStyle(DesignTokens.Colors.statusErrorText)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
        .disabled(authenticationStore.isSubmitting)
        .accessibilityIdentifier("auth.delete-account")
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

struct AccountDangerActionsSkeleton: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            DesignSkeletonLine(width: 0.3, font: DesignTokens.Typography.Expressive.emphasis)
                .designSkeleton(label: nil)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
                .beckonLedge(.card)

            DesignSkeletonLine(width: 0.34)
                .designSkeletonOnPage()
                .designSkeleton(label: nil)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
        }
    }
}
