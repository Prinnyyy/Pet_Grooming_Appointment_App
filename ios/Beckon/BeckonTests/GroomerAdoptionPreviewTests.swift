import SwiftUI
import XCTest
@testable import Beckon

@MainActor final class GroomerAdoptionPreviewTests: XCTestCase {
    func testHomeReadsFourChronologicalBookingsAndUsesLocalPreviewDependencies() async {
        let session = GroomerSandboxSession(state: .busyDay)
        await session.home.load()
        XCTAssertEqual(session.home.bookings.count, min(4, session.bookingRepository.items.filter { $0.status == .confirmed &&
            (GroomingRequestDateFormatting.parsedDate(from: $0.scheduledEnd) ?? .distantPast) >= Date() }.count))
        XCTAssertEqual(session.home.bookings.map(\.id), session.home.bookings.sortedByScheduledStart(ascending: true).map(\.id))
        XCTAssertTrue(session.home.bookings.allSatisfy { $0.groomerID == session.groomerID })
        XCTAssertNotNil(session.home.nextBooking)
    }

    func testNewHomeFitsDefaultAndAccessibilityLayouts() async {
        for state in [GroomerSandboxState.loaded, .empty] {
            let session = GroomerSandboxSession(state: state)
            await session.home.load()
            for size in [DynamicTypeSize.large, .accessibility3] {
                let view = GroomerHomeView(home: session.home, notifications: session.notifications,
                    requests: session.requests, offers: session.offers, bookings: session.bookings, chat: session.chat,
                    isActiveTab: false, unreadMessageCount: 0, requestsAction: {}, offersAction: {}, bookingAction: { _ in },
                    messagesAction: {}, availabilityAction: {}, scheduleAction: {}, accountAction: {})
                let host = UIHostingController(rootView: view.environment(\.beckonRole, .groomer)
                    .environment(\.beckonCustomerDesign, true).environment(\.dynamicTypeSize, size))
                let frame = host.sizeThatFits(in: CGSize(width: 375, height: 900))
                XCTAssertLessThanOrEqual(frame.width, 375.5)
                XCTAssertGreaterThan(frame.height, 0)
            }
        }
    }
}
