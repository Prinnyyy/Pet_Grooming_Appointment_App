import Foundation
import Testing
@testable import Beckon

@MainActor
struct HomeFlowSandboxTests {
    @Test
    func uiOnlyWizardCanVisitEveryStepWithoutRequiredInputAndNeverPublishes() async throws {
        let session = CustomerHomeFlowSandboxSession()
        defer { session.pets.invalidate() }
        await session.reload()
        let originalRequests = session.requestRepository.storedRequests
        session.requests.startCreate()
        let flow = CustomerRequestWizardState(store: session.requests)

        for step in CustomerRequestWizardStep.allCases {
            #expect(flow.currentStep == step)
            session.advanceRequestPreview(flow)
        }

        #expect(!session.requests.isShowingWizard)
        #expect(session.requestRepository.storedRequests == originalRequests)
        #expect(session.requests.publishResult == nil)
        #expect(session.requests.publicationCoordinator.pending == nil)
    }

    @Test
    func uiOnlyWizardPreservesArbitraryInputAndDoesNotChangeNormalValidation() async throws {
        let session = CustomerHomeFlowSandboxSession()
        defer { session.pets.invalidate() }
        await session.reload()
        session.requests.startCreate()
        let flow = CustomerRequestWizardState(store: session.requests)
        flow.currentStep = .service
        #expect(await flow.continueForward() == false)
        #expect(flow.currentStep == .service)
        #expect(session.requests.errorMessage != nil)

        session.advanceRequestPreview(flow)
        #expect(flow.currentStep == .time)
        #expect(session.requests.requestCalendar?.timeZone.identifier == "America/Los_Angeles")
        session.requests.streetAddress = "222"
        session.requests.city = "222"
        session.requests.zipCode = "1"
        session.requests.stateCode = nil
        #expect(await flow.continueForward() == false)
        #expect(flow.currentStep == .time)

        session.advanceRequestPreview(flow)
        #expect(flow.currentStep == .details)
        #expect(session.requests.streetAddress == "222")
        #expect(session.requests.city == "222")
        #expect(session.requests.zipCode == "1")
        #expect(session.requests.addressEditorState.confirmedAddress?.provider == "flow_sandbox")
        #expect(session.requests.errorMessage == nil)
    }

    @Test
    func homeLoadsStableFutureFixturesThroughProductionStores() async throws {
        let session = CustomerHomeFlowSandboxSession()
        defer { session.pets.invalidate() }
        await session.reload()
        #expect(session.pets.store.pets.count == 2)
        #expect(session.requests.errorMessage == nil)
        #expect(session.requests.activeRequests.count == 1)
        #expect(!session.requests.visibleActionCards.isEmpty)
        #expect(session.bookings.nearestReadError == nil)
        let booking = try #require(session.bookings.nearestBooking)
        #expect(session.notifications.unreadCount == 2)
        let request = try #require(session.requests.activeRequests.first)
        #expect(request.petID == session.pets.store.pets.first?.id)
        #expect(request.petSnapshot.name == session.pets.store.pets.first?.name)
        await session.reload()
        #expect(session.requests.activeRequests.first?.id == request.id)
        #expect(session.bookings.nearestBooking?.id == booking.id)
        #expect(try await session.bookingRepository.bookings(bookingIDs: [booking.id]) == [booking])
    }

    @Test
    func notificationAndRequestChangesStayInOneSession() async throws {
        let first = CustomerHomeFlowSandboxSession()
        let second = CustomerHomeFlowSandboxSession()
        defer { first.pets.invalidate(); second.pets.invalidate() }
        let customerID = first.pets.repository.customerID
        let request = first.requestRepository.storedRequests[0]
        _ = try await first.requestRepository.cancelRequest(requestID: request.id)
        _ = try await first.notificationRepository.markAllRead(customerID: customerID)
        await first.reload()
        await second.reload()
        #expect(first.requests.activeRequests.isEmpty)
        #expect(first.notifications.unreadCount == 0)
        #expect(second.requests.activeRequests.count == 1)
        #expect(second.notifications.unreadCount == 2)
    }

    @Test
    func injectedPreferencesAreMemoryOnlyAndDoNotLeakBetweenSessions() {
        let first = HomePreviewMemoryDefaults()
        let second = HomePreviewMemoryDefaults()
        let key = "beckon.home.preview-test.\(UUID())"
        first.set("saved", forKey: key)
        first.set(["request": "offer"], forKey: key + ".dictionary")
        first.set(["acknowledged"], forKey: key + ".array")
        first.set(Data([1, 2]), forKey: key + ".data")
        #expect(first.string(forKey: key) == "saved")
        #expect(first.dictionary(forKey: key + ".dictionary")?["request"] as? String == "offer")
        #expect(first.stringArray(forKey: key + ".array") == ["acknowledged"])
        #expect(first.data(forKey: key + ".data") == Data([1, 2]))
        #expect(second.object(forKey: key) == nil)
        #expect(UserDefaults.standard.object(forKey: key) == nil)
        first.removeObject(forKey: key)
        #expect(first.object(forKey: key) == nil)
    }
}
