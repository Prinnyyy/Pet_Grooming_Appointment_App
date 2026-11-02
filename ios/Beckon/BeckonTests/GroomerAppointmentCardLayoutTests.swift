import SwiftUI
import XCTest
@testable import Beckon

@MainActor final class GroomerAppointmentCardLayoutTests: XCTestCase {
    // A successful empty answer must not move the next section after its skeleton disappears.
    func testLoadingAndEmptyAppointmentKeepTheSameFootprint() {
        let session = GroomerSandboxSession(state: .empty)
        let view = home(session)
        for size: DynamicTypeSize in [.large, .accessibility3] {
            for width: CGFloat in [280, 350] {
                let waiting = height(view.heroBars, width: width, size: size)
                let empty = height(view.nextAppointment, width: width, size: size)
                XCTAssertEqual(empty, waiting, accuracy: 0.5, "Loading → empty at \(width) / \(size)")
            }
        }
    }

    func testKnownBookingAndItsPlaceholderFitTheSameRoomAtLargeTextSizes() async throws {
        let session = GroomerSandboxSession(state: .loaded)
        await session.home.load()
        XCTAssertNotNil(session.home.nextBooking)
        let view = home(session)
        for size: DynamicTypeSize in [.large, .accessibility3] {
            for width: CGFloat in [280, 350] {
                XCTAssertEqual(height(view.nextAppointment, width: width, size: size),
                    height(view.heroBars, width: width, size: size), accuracy: 0.5)
            }
        }
        XCTAssertGreaterThan(height(view.nextAppointment, width: 280, size: .accessibility3),
            height(view.nextAppointment, width: 280, size: .large))
    }

    func testUnavailableScheduleDoesNotCollapseTheCard() async {
        let session = GroomerSandboxSession(state: .empty)
        let repository = BookingRepositoryFake()
        repository.bookingsResult = .failure(.networkUnavailable)
        let store = GroomerHomeStore(groomerID: session.groomerID, displayName: "Alex",
            profileRepository: session.profileRepository, requestRepository: session.requestRepository,
            bookingRepository: repository, profileSnapshotCache: GroomerProfileSnapshotCacheFake())
        await store.load()
        XCTAssertTrue(store.issues.contains { $0.section == .bookings })
        let view = home(session, store: store)
        for size: DynamicTypeSize in [.large, .accessibility3] {
            XCTAssertEqual(height(view.nextAppointment, width: 280, size: size),
                height(view.heroBars, width: 280, size: size), accuracy: 0.5)
        }
    }

    private func home(_ session: GroomerSandboxSession, store: GroomerHomeStore? = nil) -> GroomerHomeView {
        GroomerHomeView(home: store ?? session.home, notifications: session.notifications,
            requests: session.requests, offers: session.offers, bookings: session.bookings, chat: session.chat,
            isActiveTab: false, unreadMessageCount: 0, requestsAction: {}, offersAction: {}, bookingAction: { _ in },
            messagesAction: {}, availabilityAction: {}, scheduleAction: {}, accountAction: {})
    }

    private func height<V: View>(_ view: V, width: CGFloat, size: DynamicTypeSize) -> CGFloat {
        let host = UIHostingController(rootView: view.frame(width: width)
            .environment(\.dynamicTypeSize, size).environment(\.beckonRole, .groomer)
            .environment(\.scenePhase, .inactive))
        return host.sizeThatFits(in: CGSize(width: width, height: 10_000)).height
    }
}
