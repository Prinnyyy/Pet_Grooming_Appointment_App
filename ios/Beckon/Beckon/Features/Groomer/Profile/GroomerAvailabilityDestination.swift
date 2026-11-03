import SwiftUI

/// Home can open the editor directly without first mounting Account or exposing unsaved default hours.
struct GroomerAvailabilityDestination: View {
    let store: GroomerProfileStore
    var body: some View {
        Group {
            if store.profile != nil {
                GroomerAvailabilityEditorView(store: store)
            } else {
                DesignPage(cascades: false) {
                    if store.isLoading || store.loadErrorMessage == nil { ProgressView("Loading availability…") }
                    else {
                        BeckonErrorBanner(title: "Availability unavailable",
                            message: store.loadErrorMessage ?? "Try loading your saved availability again.") {
                            Button("Retry") { Task { await store.load() } }
                                .buttonStyle(BeckonGuardedPlainButtonStyle())
                        }
                    }
                }
                .navigationTitle("Availability")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task { if store.profile == nil { await store.load() } }
    }
}
