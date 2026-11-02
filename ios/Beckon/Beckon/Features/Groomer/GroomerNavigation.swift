import SwiftUI
import Observation

/// Shell-owned paths and deep links. A departure pops only its outgoing tab; Store/root identity is stable.
@MainActor @Observable
final class GroomerNavigation {
    private(set) var selection: GroomerTab
    var paths: [GroomerTab: NavigationPath] = [:]
    var focusedBooking: Booking?
    var focusedConversationBookingID: UUID?
    var requestedProfileRoute: GroomerProfileRoute?
    var requestsRoute: GroomerRequestsRoute = .matches

    init(selection: GroomerTab = .home) { self.selection = selection }

    func select(_ tab: GroomerTab) {
        guard tab != selection else { return }
        let outgoing = selection
        var cut = Transaction(animation: nil); cut.disablesAnimations = true
        withTransaction(cut) {
            paths[outgoing] = NavigationPath()
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
