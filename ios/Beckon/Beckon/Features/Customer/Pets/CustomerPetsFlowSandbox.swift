#if DEBUG
import SwiftUI

// Only this composition is preview-specific. Cards, editing and feedback are production views.
struct CustomerPetsFlowSandbox: View {
    private let failsFirstSave: Bool
    @State private var session: CustomerPetsFlowSandboxSession

    init(failsFirstSave: Bool = false) {
        self.failsFirstSave = failsFirstSave
        _session = State(initialValue: CustomerPetsFlowSandboxSession(failsFirstSave: failsFirstSave))
    }

    var body: some View {
        @Bindable var store = session.store
        NavigationStack {
            ScrollView {
                CustomerHomePetsSection(store: store)
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.vertical, DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Colors.appBackground)
            .navigationTitle("Pet flow sandbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Reload pets", systemImage: "arrow.clockwise") {
                        Task { await store.load() }
                    }
                    .disabled(store.isBusy)
                    .help("Reload pets")
                    Button("Reset sandbox", systemImage: "arrow.counterclockwise") {
                        session.invalidate()
                        session = CustomerPetsFlowSandboxSession(failsFirstSave: failsFirstSave)
                    }
                    .help("Reset sandbox")
                }
            }
            .sheet(isPresented: $store.isShowingPetForm) {
                CustomerPetFormView(store: store)
            }
            .background { CustomerPetsStatusView(store: store) }
        }
        .environment(\.beckonFeedbackCenter, session.feedbackCenter)
        .overlay(alignment: .bottom) {
            BeckonGlobalFeedbackOverlay(center: session.feedbackCenter,
                bottomPadding: BeckonGlobalFeedbackOverlay.sheetBottomClearance)
        }
        .environment(\.beckonCustomerDesign, true)
        .tint(DesignTokens.Colors.customerDeep)
        .preferredColorScheme(.light)
        .task { await store.load() }
        .id(session.id)
    }
}

@MainActor
final class CustomerPetsFlowSandboxSession {
    let id = UUID()
    let directory: URL
    let repository: CustomerPetsPreviewRepository
    let store: CustomerPetsStore
    let feedbackCenter = BeckonFeedbackCenter()

    init(failsFirstSave: Bool = false, repository: CustomerPetsPreviewRepository = CustomerPetsPreviewRepository()) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeckonPetFlowSandbox", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        self.directory = directory
        self.repository = repository
        repository.failsNextSave = failsFirstSave
        store = CustomerPetsStore(
            customerID: repository.customerID,
            repository: repository,
            photoCache: FileCustomerPetPhotoCache(directoryURL: directory.appendingPathComponent("photos")),
            pendingCreationDirectory: directory.appendingPathComponent("pending"),
            sessionIsCurrent: { repository.isActive }
        )
    }

    func invalidate() {
        repository.isActive = false
        try? FileManager.default.removeItem(at: directory)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}

#Preview("Pet flow - edit and save") {
    CustomerPetsFlowSandbox()
}

#Preview("Pet flow - unconfirmed save") {
    CustomerPetsFlowSandbox(failsFirstSave: true)
}
#endif
