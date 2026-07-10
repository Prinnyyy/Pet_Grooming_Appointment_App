import SwiftUI

nonisolated enum GroomerProfileRoute: String, Hashable, Identifiable, Sendable {
    case availability

    var id: Self { self }

    static func activatedRoute(
        requested: Self?,
        isProfileLoaded: Bool
    ) -> Self? {
        guard isProfileLoaded else { return nil }
        return requested
    }
}

struct GroomerProfileManagementView: View {
    @State private var store: GroomerProfileStore
    @Binding private var requestedRoute: GroomerProfileRoute?
    @State private var activeRoute: GroomerProfileRoute?
    let accountContent: AnyView?
    let onSignOut: (() -> Void)?

    init(
        groomerID: UUID,
        repository: any GroomerProfileRepository,
        debugRecorder: AppDebugEventRecorder? = nil,
        requestedRoute: Binding<GroomerProfileRoute?> = .constant(nil),
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
        _requestedRoute = requestedRoute
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
        .navigationDestination(item: $activeRoute) { route in
            switch route {
            case .availability:
                GroomerAvailabilityEditorView(store: store)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
        .task {
            await store.load()
            activateRequestedRouteIfReady()
        }
        .onChange(of: requestedRoute) { _, _ in
            activateRequestedRouteIfReady()
        }
    }

    private func activateRequestedRouteIfReady() {
        guard let route = GroomerProfileRoute.activatedRoute(
            requested: requestedRoute,
            isProfileLoaded: store.profile != nil
        ) else {
            return
        }

        requestedRoute = nil
        activeRoute = route
    }
}
