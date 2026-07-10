import SwiftUI

struct GroomerProfileManagementView: View {
    @State private var store: GroomerProfileStore
    let accountContent: AnyView?
    let onSignOut: (() -> Void)?

    init(
        groomerID: UUID,
        repository: any GroomerProfileRepository,
        debugRecorder: AppDebugEventRecorder? = nil,
        accountContent: AnyView? = nil,
        onSignOut: (() -> Void)? = nil
    ) {
        _store = State(
            initialValue: GroomerProfileStore(
                groomerID: groomerID,
                repository: repository,
                debugRecorder: debugRecorder
            )
        )
        self.accountContent = accountContent
        self.onSignOut = onSignOut
    }

    var body: some View {
        @Bindable var store = store

        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            if store.shouldShowInitialLoading {
                BeckonLoadingView(
                    title: "Loading Groomer Profile…",
                    message: "We are preparing your profile, services, and portfolio settings.",
                    accent: .groomer
                )
                .accessibilityIdentifier("groomer.profile.loading")
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomerAccountHomeView(
                            store: store,
                            accountContent: accountContent,
                            onSignOut: onSignOut
                        )
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.xl)
                    .padding(.bottom, 120)
                }
                .accessibilityIdentifier("groomer.account.home")
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            GroomerProfileStatusView(store: store)
        }
        .sheet(isPresented: $store.isShowingServiceForm) {
            GroomerServiceFormView(store: store)
        }
        .task {
            await store.load()
        }
    }
}
