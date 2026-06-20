import SwiftUI

struct AuthenticationGateView: View {
    @Bindable var store: AuthenticationStore

    var body: some View {
        Group {
            switch store.rootState {
            case .loading:
                ZStack {
                    DesignTokens.Colors.background
                        .ignoresSafeArea()

                    ProgressView("Restoring session…")
                        .accessibilityIdentifier("auth.loading")
                }

            case .signedOut:
                AuthenticationView(store: store)

            case let .signedIn(session):
                OnboardingRequiredView(session: session, store: store)
            }
        }
        .task {
            await store.start()
        }
    }
}
