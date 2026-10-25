import SwiftUI

struct CustomerAccountView: View {
    @Environment(\.customerMarketplaceSession) private var marketplace
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
            BeckonExpressiveBackdrop()

            ScrollView {
                BeckonCascade(spacing: DesignTokens.Layout.sectionSpacing) {
                    BeckonPageTitle("Account")

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

                    // What the person uses most, as two tiles: their own details and the groomers they saved.
                    DesignShortcutRow {
                        DesignShortcutTile(
                            title: "Profile settings",
                            summary: "Photo, nickname, contact, and address",
                            systemImage: "person.crop.circle"
                        ) {
                            CustomerProfileSettingsView(store: store)
                        }

                        if let marketplace {
                            DesignShortcutTile(
                                title: "Saved groomers",
                                summary: "Groomers you have hearted",
                                systemImage: "heart"
                            ) {
                                CustomerFavoriteGroomersView(marketplace: marketplace)
                            }
                            .accessibilityIdentifier("account.saved-groomers")
                        }
                    }

                    BeckonSection("Help") {
                        AccountReleaseLinksSection(accent: .customer)
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
                                accent: .customer
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
                .beckonTracksScroll()
        }
        .task {
            await store.load()
        }
        .background {
            CustomerProfileStatusView(store: store)
        }
        .environment(\.beckonCustomerDesign, true)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("customer.account")
    }
}
