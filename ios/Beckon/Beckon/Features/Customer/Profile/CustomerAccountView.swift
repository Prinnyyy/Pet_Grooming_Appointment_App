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

                    BeckonAccountIdentityHeader(
                        displayName: store.profileDisplayName,
                        detailText: store.profileDetailText,
                        roleTitle: "Pet Owner",
                        roleSystemImage: "pawprint.fill",
                        roleTone: .customer
                    ) {
                        CustomerAvatarImage(
                            data: store.avatarPhotoData,
                            size: BeckonAccountLayoutPolicy.identityAvatarSize,
                            placeholderSize: 30
                        )
                    }

                    BeckonSection("Profile") {
                        BeckonGroupedSurface {
                            BeckonSettingsNavigationRow(
                                title: "Profile Settings",
                                summary: "Photo, nickname, contact, and address",
                                systemImage: "person.crop.circle",
                                accent: .customer
                            ) {
                                CustomerProfileSettingsView(store: store)
                            }
                        }
                    }

                    BeckonSection("Support") {
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
                                title: "Debug Console",
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
