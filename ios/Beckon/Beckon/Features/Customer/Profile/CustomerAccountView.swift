import SwiftUI

struct CustomerAccountView: View {
    @Environment(\.customerNavigation) private var navigation
    @Environment(\.customerMarketplaceSession) private var marketplace
    let session: AuthSessionSnapshot
    let profile: MarketplaceProfile
    @Bindable var authenticationStore: AuthenticationStore
    @State private var store: CustomerProfileStore
    @State private var showsProfileSettings = false
    @State private var showsDebugConsole = false
    /// The first load is over (answered, or a saved profile can be shown): until then everything under the title is bars, not
    /// "Pet Owner" and links that look ready to press (design).
    private var profileSettled: Bool { store.hasLoadedOnce || store.profile != nil || store.cachedProfileSnapshot != nil }

    #if DEBUG
    init(sandbox: CustomerSandboxSession) {
        session = sandbox.authSession
        profile = sandbox.marketplaceProfile
        authenticationStore = sandbox.authentication
        _store = State(initialValue: sandbox.profile)
    }
    #endif

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
            BeckonExpressiveBackdrop()

            ScrollView {
                BeckonCascade(spacing: DesignTokens.Layout.sectionSpacing) {
                    BeckonPageTitle("Account")

                    waits {
                        BeckonAccountIdentityHeader(
                            displayName: store.profileDisplayName,
                            detailText: store.profileDetailText,
                            roleTitle: "Pet owner",
                            roleSystemImage: "pawprint.fill",
                            roleAccent: .customer
                        ) {
                            CustomerAvatarImage(
                                data: store.avatarPhotoData,
                                size: BeckonAccountLayoutPolicy.identityAvatarSize,
                                placeholderSize: 30
                            )
                        }
                    } placeholder: {
                        BeckonAccountIdentitySkeleton(
                            roleTitle: "Pet owner",
                            roleSystemImage: "pawprint.fill",
                            roleAccent: .customer
                        )
                    }

                    // What the person uses most, as two tiles: their own details and the groomers they saved.
                    waits {
                        DesignShortcutRow {
                            DesignShortcutTile(
                                title: "Profile settings",
                                summary: "Photo, nickname, contact, and address",
                                systemImage: "person.crop.circle", action: { showsProfileSettings = true }
                            ) {
                                CustomerProfileSettingsView(store: store)
                            }

                            if let marketplace {
                                DesignShortcutTile(
                                    title: "Saved groomers",
                                    summary: "Groomers you have hearted",
                                    systemImage: "heart",
                                    action: navigation.map { owner in { owner.open(.savedGroomers) } }
                                ) {
                                    CustomerFavoriteGroomersView(marketplace: marketplace)
                                }
                                .accessibilityIdentifier("account.saved-groomers")
                            }
                        }
                    } placeholder: {
                        DesignShortcutRow {
                            DesignShortcutTileSkeleton()
                            if marketplace != nil { DesignShortcutTileSkeleton() }
                        }
                    }

                    waits {
                        BeckonSection("Help") {
                            AccountReleaseLinksSection(accent: .customer)
                        }
                    } placeholder: {
                        BeckonSettingsSectionSkeleton(summaries: [false, false])
                    }

                    if let errorMessage = authenticationStore.errorMessage {
                        BeckonErrorBanner(
                            title: "Account action failed",
                            message: errorMessage
                        )
                        .accessibilityIdentifier("auth.error")
                    }

                    #if DEBUG
                    waits {
                        BeckonSection("Development") {
                            BeckonGroupedSurface {
                                BeckonSettingsNavigationRow(
                                    title: "Debug console",
                                    summary: "Runtime events and diagnostics",
                                    systemImage: "ladybug",
                                    accent: .customer, action: { showsDebugConsole = true }
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
                    } placeholder: {
                        BeckonSettingsSectionSkeleton(summaries: [true])
                    }
                    #endif

                    waits {
                        BeckonSection("Account access") {
                            AccountDangerActions(
                                authenticationStore: authenticationStore
                            )
                        }
                    } placeholder: {
                        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                            DesignSkeletonLine(width: 0.4, font: DesignTokens.Typography.Expressive.section)
                                .designSkeletonOnPage()
                                .designSkeleton(label: nil)
                            AccountDangerActionsSkeleton()
                        }
                    }
                }
                .beckonPageInsets()
            }
                .beckonTracksScroll()
        }
        .task { await store.load() }
        .navigationDestination(isPresented: $showsProfileSettings) { CustomerProfileSettingsView(store: store) }
        #if DEBUG
        .navigationDestination(isPresented: $showsDebugConsole) {
            DebugPanelView(diagnostics: DebugDiagnostics.current(session: session, profile: profile))
        }
        #endif
        .onChange(of: navigation?.handoffGeneration) { _, _ in
            showsProfileSettings = false
            showsDebugConsole = false
        }
        .background {
            CustomerProfileStatusView(store: store)
        }
        .environment(\.beckonCustomerDesign, true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("customer.account")
    }

    /// One block of the page that waits for the profile: its placeholder until the first load is over, then the block itself, all
    /// blocks together.
    private func waits<Content: View, Placeholder: View>(
        @ViewBuilder _ content: () -> Content,
        @ViewBuilder placeholder: () -> Placeholder
    ) -> some View {
        DesignReveal(isLoading: !profileSettled, content: content, placeholder: placeholder)
    }
}
