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
    let onSignOut: (() -> Void)?
    init(groomerID: UUID, repository: any GroomerProfileRepository, debugRecorder: AppDebugEventRecorder? = nil,
         requestedRoute: Binding<GroomerProfileRoute?> = .constant(nil), accountContent: AnyView? = nil,
         onSignOut: (() -> Void)? = nil) {
        _store = State(initialValue: GroomerProfileStore(groomerID: groomerID, repository: repository, debugRecorder: debugRecorder))
        _requestedRoute = requestedRoute
        self.onSignOut = onSignOut
    }
    var body: some View {
        GroomerAccountView(store: store, requestedRoute: $requestedRoute, onSignOut: { onSignOut?() })
    }
}
