import SwiftUI
import Observation

nonisolated enum GroomerDestination: Hashable {
    case booking(UUID)
    case bookingConversation(UUID)
    case availability
}

/// Shell-owned paths and deep links. A departure pops only its outgoing tab; Store/root identity is stable.
@MainActor @Observable
final class GroomerNavigation {
    private(set) var selection: GroomerTab
    var paths: [GroomerTab: NavigationPath] = [:]
    private(set) var resetCounts: [GroomerTab: Int] = [:]
    var focusedBooking: Booking?
    var focusedConversationBookingID: UUID?
    var requestedProfileRoute: GroomerProfileRoute?
    var requestsRoute: GroomerRequestsRoute = .matches

    init(selection: GroomerTab = .home) { self.selection = selection }

    /// A detail belongs to the current stack, regardless of its feature owner.
    func open(_ destination: GroomerDestination) {
        paths[selection, default: NavigationPath()].append(destination)
    }

    func select(_ tab: GroomerTab) {
        guard tab != selection else { return }
        let outgoing = selection
        var cut = Transaction(animation: nil); cut.disablesAnimations = true
        withTransaction(cut) {
            paths[outgoing] = NavigationPath()
            resetCounts[outgoing, default: 0] += 1
            switch outgoing {
            case .home: break
            case .requests: requestsRoute = .matches
            case .bookings: focusedBooking = nil
            case .messages: focusedConversationBookingID = nil
            case .account: requestedProfileRoute = nil
            }
            selection = tab
        }
    }
}
