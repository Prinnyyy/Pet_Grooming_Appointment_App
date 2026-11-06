import SwiftUI

nonisolated enum ChatConversationTarget: Hashable {
    case conversation(UUID)
    case bookingConversation(UUID)
}

/// Resolve outside the transition, with the existing repository's participant checks intact.
struct ChatConversationDestination: View {
    let route: ChatConversationTarget
    let role: UserRole
    let participantID: UUID
    let store: ChatStore
    var booking: Booking? = nil
    @Environment(\.scenePhase) private var scenePhase
    @State private var conversation: ChatConversation?
    @State private var isLoading = true
    @State private var retry = 0

    private var previewConversation: ChatConversation? {
        if let conversation { return conversation }
        if let booking { return store.conversation(for: booking) }
        if case .bookingConversation(let id) = route { return store.cachedConversation(bookingID: id) }
        if case .conversation(let id) = route { return store.conversations.first { $0.id == id } }
        return nil
    }

    var body: some View {
        Group {
            if let shown = conversation ?? previewConversation {
                ChatThreadView(participantID: participantID, role: role, conversation: shown, store: store)
            } else if isLoading {
                ChatThreadLoadingView(
                    title: previewConversation?.listTitle(for: role) ?? booking?.partnerDisplayTitle(for: role) ?? "Messages",
                    avatarPhotoData: previewConversation?.counterpartAvatarPhotoData, role: role,
                    counterpartID: role == .customer ? (previewConversation?.groomerID ?? booking?.groomerID) : (previewConversation?.customerID ?? booking?.customerID))
            } else {
                DesignPage(cascades: false) {
                    BeckonErrorBanner(title: "Conversation unavailable", message: store.errorMessage ?? "Try opening this conversation again.") {
                        Button("Retry") { isLoading = true; retry += 1 }
                            .buttonStyle(BeckonGuardedPlainButtonStyle())
                    }
                }
            }
        }
        .task(id: scenePhase == .active ? retry : -1) {
            guard scenePhase == .active, isLoading else { return }
            if let cached = previewConversation {
                conversation = cached
                isLoading = false
                return
            }
            let resolved: ChatConversation?
            switch route {
            case .conversation(let id): resolved = await store.resolveConversation(conversationID: id)
            case .bookingConversation(let id): resolved = await store.resolveConversation(bookingID: id)
            }
            guard !Task.isCancelled else { return }
            conversation = resolved
            isLoading = false
        }
        // ChatThreadView owns its subscription lifecycle for every entry route.
    }
}
