import SwiftUI
import Testing
@testable import Beckon

@MainActor struct GroomerNavigationTests {
    @Test func secondaryDestinationsStayInTheirOriginatingTabAndPopInOrder() {
        for tab in GroomerTab.allCases {
            let navigation = GroomerNavigation(selection: tab)
            let untouched = NavigationPath([UUID()])
            let other: GroomerTab = tab == .messages ? .account : .messages
            navigation.paths[other] = untouched
            let booking = GroomerDestination.booking(UUID())
            let chat = GroomerDestination.bookingConversation(UUID())
            navigation.open(booking)
            navigation.open(chat)
            navigation.open(.conversation(UUID()))
            #expect(navigation.paths[tab]?.count == 3)
            navigation.paths[tab]?.removeLast()
            #expect(navigation.selection == tab)
            #expect(navigation.paths[tab] == NavigationPath([booking, chat]))
            navigation.paths[tab]?.removeLast()
            #expect(navigation.paths[tab] == NavigationPath([booking]))
            #expect(navigation.paths[other] == untouched)
            #expect(navigation.resetCounts.isEmpty)
            navigation.paths[tab]?.removeLast()
            navigation.open(.availability)
            #expect(navigation.paths[tab] == NavigationPath([GroomerDestination.availability]))
            navigation.select(other)
            #expect(navigation.paths[tab]?.isEmpty == true)
        }
    }

    @Test func departureClearsOnlyOutgoingPathAndLinks() {
        let navigation = GroomerNavigation(selection: .messages)
        let id = UUID()
        navigation.paths[.messages] = NavigationPath([id])
        navigation.paths[.account] = NavigationPath([UUID()])
        navigation.focusedConversationBookingID = id
        navigation.requestedProfileRoute = .availability
        navigation.select(.account)
        #expect(navigation.paths[.messages]?.isEmpty == true)
        #expect(navigation.resetCounts[.messages] == 1)
        #expect(navigation.resetCounts[.account] == nil)
        #expect(navigation.focusedConversationBookingID == nil)
        #expect(navigation.paths[.account]?.count == 1)
        #expect(navigation.requestedProfileRoute == .availability)
        navigation.select(.home)
        #expect(navigation.paths[.account]?.isEmpty == true)
        #expect(navigation.resetCounts[.account] == 1)
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
        #expect(navigation.resetCounts[.requests] == nil)
        navigation.select(.home)
        #expect(navigation.requestsRoute == .matches)
    }
}
