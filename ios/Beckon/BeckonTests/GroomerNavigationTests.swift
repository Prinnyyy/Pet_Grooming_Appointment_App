import SwiftUI
import Testing
@testable import Beckon

@MainActor struct GroomerNavigationTests {
    @Test func departureClearsOnlyOutgoingPathAndLinks() {
        let navigation = GroomerNavigation(selection: .messages)
        let id = UUID()
        navigation.paths[.messages] = NavigationPath([id])
        navigation.paths[.account] = NavigationPath([UUID()])
        navigation.focusedConversationBookingID = id
        navigation.requestedProfileRoute = .availability
        navigation.select(.account)
        #expect(navigation.paths[.messages]?.isEmpty == true)
        #expect(navigation.focusedConversationBookingID == nil)
        #expect(navigation.paths[.account]?.count == 1)
        #expect(navigation.requestedProfileRoute == .availability)
        navigation.select(.home)
        #expect(navigation.paths[.account]?.isEmpty == true)
        #expect(navigation.requestedProfileRoute == nil)
    }

    @Test func incomingRequestHandoffAndRepeatedSelectionKeepTarget() {
        let navigation = GroomerNavigation()
        navigation.requestsRoute = .offers
        navigation.select(.requests)
        #expect(navigation.requestsRoute == .offers)
        navigation.paths[.requests] = NavigationPath([UUID()])
        navigation.select(.requests)
        #expect(navigation.paths[.requests]?.count == 1)
        navigation.select(.home)
        #expect(navigation.requestsRoute == .matches)
    }
}
