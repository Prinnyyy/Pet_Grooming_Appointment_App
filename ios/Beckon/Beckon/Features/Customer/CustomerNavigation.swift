import SwiftUI
import Observation

/// Lightweight destinations owned by the customer shell, not the page that happened to open them.
enum CustomerDestination: Hashable {
    case notifications, history, savedGroomers
    case grooming(GroomingRoute)
    case offers(UUID)
    case offer(requestID: UUID, offerID: UUID)
    case conversation(UUID), bookingConversation(UUID)

    var tab: CustomerTab {
        switch self {
        case .notifications: .home
        case .savedGroomers: .account
        case .conversation, .bookingConversation: .messages
        default: .requests
        }
    }
}

@MainActor @Observable
final class CustomerNavigation {
    var selection: CustomerTab = .home
    var home: [CustomerDestination] = []
    var grooming: [CustomerDestination] = []
    var messages: [CustomerDestination] = []
    var account: [CustomerDestination] = []
    var focusedGroomingID: UUID?
    private(set) var handoffGeneration = 0

    subscript(tab: CustomerTab) -> [CustomerDestination] {
        get {
            switch tab {
            case .home: home
            case .requests, .bookings: grooming
            case .messages: messages
            case .account: account
            }
        }
        set {
            switch tab {
            case .home: home = newValue
            case .requests, .bookings: grooming = newValue
            case .messages: messages = newValue
            case .account: account = newValue
            }
        }
    }

    func open(_ destination: CustomerDestination, replacing: Bool = false) {
        let target = destination.tab
        if selection != target || replacing {
            cut(to: target) { self[target] = [destination] }
        } else if self[target].last != destination {
            self[target].append(destination)
        }
    }

    func showGrooming(_ id: UUID?) {
        cut(to: .requests) {
            grooming = []
            focusedGroomingID = id
        }
    }

    func showHome() { cut(to: .home) { home = [] } }

    /// Manual tab selection bypasses this method and preserves history. Action-driven handoffs
    /// reset paths in one transaction without changing view identities or reconstructing stores.
    private func cut(to tab: CustomerTab, update: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self[selection] = []
            handoffGeneration &+= 1
            update()
            selection = tab
        }
    }
}

private struct CustomerNavigationKey: EnvironmentKey {
    static let defaultValue: CustomerNavigation? = nil
}
extension EnvironmentValues {
    var customerNavigation: CustomerNavigation? {
        get { self[CustomerNavigationKey.self] }
        set { self[CustomerNavigationKey.self] = newValue }
    }
}

/// A tab's first deep link is applied after its native stack mounts. This avoids asking UIKit
/// to create the tab root and reconcile a non-empty navigation path in the same layout pass.
struct CustomerNavigationStack<Content: View>: View {
    let navigation: CustomerNavigation
    let tab: CustomerTab
    @ViewBuilder let content: Content
    @State private var mounted = false

    var body: some View {
        NavigationStack(path: Binding(get: { mounted ? navigation[tab] : [] }, set: {
            if mounted { navigation[tab] = $0 }
        })) { content }
        .task {
            guard !mounted else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { mounted = true }
        }
    }
}

/// Production uses the shell's value route. A standalone preview keeps the same local destination.
struct CustomerNavigationLink<Destination: View, Label: View>: View {
    @Environment(\.customerNavigation) private var navigation
    let route: CustomerDestination
    @ViewBuilder var destination: () -> Destination
    @ViewBuilder var label: () -> Label

    var body: some View {
        if let navigation {
            Button { navigation.open(route) } label: { label() }
        } else {
            NavigationLink(destination: destination, label: label)
        }
    }
}

/// Resolve outside the transition, with the existing repository's participant checks intact.
struct CustomerConversationDestination: View {
    let route: CustomerDestination
    let participantID: UUID
    let store: ChatStore
    var booking: Booking? = nil
    @Environment(\.scenePhase) private var scenePhase
    @State private var conversation: ChatConversation?
    @State private var isLoading = true
    @State private var initialMessagesPrepared = false
    @State private var retry = 0

    private var previewConversation: ChatConversation? {
        if let conversation { return conversation }
        if let booking { return store.conversation(for: booking) }
        if case .conversation(let id) = route { return store.conversations.first { $0.id == id } }
        return nil
    }

    var body: some View {
        DesignReveal(isLoading: isLoading) {
            if let conversation {
                ChatThreadView(participantID: participantID, role: .customer, conversation: conversation,
                    store: store, initialMessagesPrepared: initialMessagesPrepared)
            } else {
                DesignPage(cascades: false) {
                    BeckonErrorBanner(title: "Conversation unavailable", message: store.errorMessage ?? "Try opening this conversation again.") {
                        Button("Retry") { isLoading = true; retry += 1 }
                    }
                }
            }
        } placeholder: {
            ChatThreadLoadingView(
                title: previewConversation?.listTitle(for: .customer) ?? booking?.partnerDisplayTitle(for: .customer) ?? "Messages",
                avatarPhotoData: previewConversation?.counterpartAvatarPhotoData)
        }
        .task(id: scenePhase == .active ? retry : -1) {
            guard scenePhase == .active, isLoading else { return }
            let resolved: ChatConversation?
            switch route {
            case .conversation(let id): resolved = await store.resolveConversation(conversationID: id)
            case .bookingConversation(let id): resolved = await store.resolveConversation(bookingID: id)
            default: resolved = nil
            }
            guard !Task.isCancelled else { return }
            conversation = resolved
            if let resolved, !store.hasLoadedMessages(for: resolved.id) {
                store.deferReadAcknowledgement(for: resolved.id)
                await store.prepareMessages(for: resolved)
                guard !Task.isCancelled else { return }
                initialMessagesPrepared = true
            }
            isLoading = false
        }
        .onDisappear {
            if let conversation { store.stopMessageSubscription(for: conversation.id) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, let conversation { store.stopMessageSubscription(for: conversation.id) }
        }
    }
}

/// A concrete destination boundary keeps the tab shell from specializing every page tree.
struct CustomerRouteDestination: View {
    let route: CustomerDestination
    let customerID: UUID?
    let notificationStore: CustomerNotificationsStore?
    let requestStore: CustomerRequestsStore?
    let bookingsStore: BookingsStore?
    let chatStore: ChatStore?
    let marketplace: CustomerMarketplaceSession?
    let onOpenChat: (Booking) -> Void

    // Type erasure is limited to this heterogeneous route boundary. The selected page retains
    // its own concrete body; unrelated page types need not be specialized while navigating.
    var body: AnyView {
        switch route {
        case .notifications:
            if let notificationStore {
                return AnyView(CustomerNotificationsView(store: notificationStore, requestStore: requestStore,
                    bookingStore: bookingsStore, chatStore: chatStore))
            }
        case .savedGroomers:
            if let marketplace { return AnyView(CustomerFavoriteGroomersView(marketplace: marketplace)) }
        case .history:
            if let requestStore, let bookingsStore {
                return AnyView(GroomingHistoryView(requestStore: requestStore, bookingsStore: bookingsStore, onOpenChat: onOpenChat))
            }
        case .grooming(let target):
            switch target {
            case .request(let id):
                if let requestStore {
                    return AnyView(GroomingDetailView(target: .request(id), requestStore: requestStore,
                        bookingsStore: bookingsStore, onOpenChat: onOpenChat))
                }
            case .booking(let id), .newBooking(let id):
                if let bookingsStore {
                    return AnyView(GroomingDetailView(target: .booking(id), requestStore: requestStore,
                        bookingsStore: bookingsStore, onOpenChat: onOpenChat, celebratesNewBooking: target == .newBooking(id)))
                }
            }
        case .offers(let id):
            if let requestStore { return AnyView(CustomerRequestOffersView(requestID: id, store: requestStore)) }
        case .offer(let requestID, let offerID):
            if let requestStore, let request = requestStore.request(withID: requestID) {
                return AnyView(CustomerOfferDetailView(request: request, offerID: offerID, store: requestStore))
            }
        case .conversation, .bookingConversation:
            if let customerID, let chatStore {
                let booking: Booking? = if case .bookingConversation(let id) = route { bookingsStore?.booking(withID: id) } else { nil }
                return AnyView(CustomerConversationDestination(route: route, participantID: customerID, store: chatStore, booking: booking))
            }
        }
        return AnyView(EmptyView())
    }
}
