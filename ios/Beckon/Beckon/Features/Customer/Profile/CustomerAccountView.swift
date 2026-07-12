import SwiftUI

struct CustomerAccountView: View {
    let session: AuthSessionSnapshot
    let profile: MarketplaceProfile
    @Bindable var authenticationStore: AuthenticationStore
    @State private var store: CustomerProfileStore

    init(
        session: AuthSessionSnapshot,
        profile: MarketplaceProfile,
        authenticationStore: AuthenticationStore,
        repository: any CustomerProfileRepository,
        debugRecorder: AppDebugEventRecorder? = nil
    ) {
        self.session = session
        self.profile = profile
        self.authenticationStore = authenticationStore
        _store = State(
            initialValue: CustomerProfileStore(
                customerID: profile.userID,
                initialDisplayName: profile.displayName,
                sessionEmail: session.email,
                repository: repository,
                debugRecorder: debugRecorder
            )
        )
    }

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                    BeckonPageTitle("Account")

                    CustomerAccountIdentityHeader(
                        displayName: store.profileDisplayName,
                        detailText: store.profileDetailText,
                        avatarPhotoData: store.avatarPhotoData
                    )

                    BeckonSection("Profile") {
                        BeckonGroupedSurface {
                            NavigationLink {
                                CustomerProfileSettingsView(store: store)
                            } label: {
                                BeckonSettingsRowLabel(
                                    title: "Profile Settings",
                                    summary: "Photo, nickname, contact, and address",
                                    systemImage: "person.crop.circle",
                                    accent: .customer
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    BeckonSection("Support") {
                        CustomerAccountSupportSurface()
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
                            NavigationLink {
                                DebugPanelView(
                                    diagnostics: DebugDiagnostics.current(
                                        session: session,
                                        profile: profile
                                    )
                                )
                            } label: {
                                BeckonSettingsRowLabel(
                                    title: "Debug Console",
                                    summary: "Runtime events and diagnostics",
                                    systemImage: "ladybug",
                                    accent: .customer
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("account.debug-console")
                        }
                    }
                    #endif

                    BeckonSection("Account Access") {
                        AccountDangerActions(
                            authenticationStore: authenticationStore
                        )
                    }
                }
                .beckonPageInsets()
            }
        }
        .task {
            await store.load()
        }
        .background {
            CustomerProfileStatusView(store: store)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("customer.account")
    }
}

private struct CustomerAccountIdentityHeader: View {
    let displayName: String
    let detailText: String
    let avatarPhotoData: Data?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            CustomerAvatarImage(
                data: avatarPhotoData,
                size: 76,
                placeholderSize: 30
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(displayName)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detailText)
                    .font(DesignTokens.Typography.supporting)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                BeckonStatusChip(
                    "Pet Owner",
                    systemImage: "pawprint.fill",
                    tone: .customer
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CustomerAccountSupportSurface: View {
    private let dividerLeadingInset =
        DesignTokens.Layout.rowHorizontalInset
        + DesignTokens.Metrics.settingsIconSlot
        + DesignTokens.Spacing.md

    var body: some View {
        BeckonGroupedSurface {
            VStack(spacing: 0) {
                releaseLink(
                    title: "Privacy Policy",
                    systemImage: "hand.raised",
                    destination: AppReleaseLinks.privacyPolicy,
                    accessibilityIdentifier: "account.privacy-policy"
                )

                Divider()
                    .overlay(DesignTokens.Colors.divider)
                    .padding(.leading, dividerLeadingInset)

                releaseLink(
                    title: "Support",
                    systemImage: "questionmark.circle",
                    destination: AppReleaseLinks.support,
                    accessibilityIdentifier: "account.support"
                )
            }
        }
    }

    private func releaseLink(
        title: String,
        systemImage: String,
        destination: URL,
        accessibilityIdentifier: String
    ) -> some View {
        Link(destination: destination) {
            BeckonSettingsRowLabel(
                title: title,
                systemImage: systemImage,
                accent: .customer,
                trailingSystemImage: "arrow.up.right"
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
