import Foundation
import Testing
@testable import Beckon

struct BookingReviewContextTests {
    @Test @MainActor
    func contextChangeReloadsWithoutResubmittingReview() async {
        let booking = BookingsStoreTests.booking(status: .completed)
        let first = BookingReviewContext(bookingID: booking.id, contextRevision: UUID(),
            evidenceContextVersion: 2, serviceAt: nil, allowedKeys: [])
        let second = BookingReviewContext(bookingID: booking.id, contextRevision: UUID(),
            evidenceContextVersion: 2, serviceAt: nil, allowedKeys: [])
        let repository = BookingRepositoryFake(bookingsResult: .success([booking]))
        repository.reviewContextResult = .success(first)
        let store = BookingsStore(participantID: booking.customerID, role: .customer, repository: repository)
        await store.loadReviewContext(for: booking)
        repository.reviewContextResult = .success(second)
        repository.reviewResult = .failure(.reviewContextChanged)
        await store.createReview(for: booking, rating: 2, content: "Draft survives a context change")
        #expect(repository.reviewCallCount == 1)
        #expect(repository.lastReviewDraft?.rating == 2)
        #expect(repository.lastReviewDraft?.content == "Draft survives a context change")
        #expect(store.reviewContexts[booking.id]?.contextRevision == second.contextRevision)
        #expect(store.errorMessage != nil)
    }
    @Test @MainActor
    func reviewCannotSubmitBeforeTrustedContextLoads() async {
        let booking = BookingsStoreTests.booking(status: .completed)
        let repository = BookingRepositoryFake(bookingsResult: .success([booking]))
        let store = BookingsStore(participantID: booking.customerID, role: .customer, repository: repository)
        await store.createReview(for: booking, rating: 5, content: "Good service")
        #expect(repository.reviewCallCount == 0)
        #expect(store.errorMessage != nil)
    }

    @Test @MainActor
    func contextFailureDoesNotInventSelections() async {
        let booking = BookingsStoreTests.booking(status: .completed, serviceType: .fullGroom)
        let repository = BookingRepositoryFake(bookingsResult: .success([booking]))
        let store = BookingsStore(participantID: booking.customerID, role: .customer, repository: repository)
        await store.loadReviewContext(for: booking)
        #expect(store.reviewContexts[booking.id] == nil)
        #expect(store.reviewContextErrors[booking.id] != nil)
    }

    @Test @MainActor
    func sessionChangeDiscardsLateContext() async {
        let booking = BookingsStoreTests.booking(status: .completed)
        let repository = BookingRepositoryFake(bookingsResult: .success([booking]))
        repository.reviewContextResult = .success(BookingReviewContext(bookingID: booking.id, contextRevision: UUID(),
            evidenceContextVersion: 2, serviceAt: nil, allowedKeys: []))
        let session = ReviewContextSession()
        repository.onReviewContext = { session.isCurrent = false }
        let store = BookingsStore(participantID: booking.customerID, role: .customer, repository: repository,
            sessionIsCurrent: { session.isCurrent })
        await store.loadReviewContext(for: booking)
        #expect(store.reviewContexts[booking.id] == nil)
        #expect(store.reviewContextErrors[booking.id] == nil)
    }

    @Test @MainActor
    func publicRatingUsesExactTotalWithoutDoubleRounding() {
        let profile = GroomerProfile(userID: UUID(), businessName: nil, bio: nil, yearsExperience: nil,
            baseCity: nil, baseState: nil, serviceRadiusMiles: nil, serviceLocationMode: nil,
            ratingAverage: 4.35, ratingCount: 2500, isActive: true, isVerified: false, ratingSum: 10874)
        #expect(profile.exactRatingAverage == 4.3496)
        #expect(profile.exactRatingAverage?.formatted(.number.precision(.fractionLength(1))) == "4.3")
    }

    @Test
    func contextDecodesServerKeysWithoutAddingInferredTraits() throws {
        let booking = UUID(), revision = UUID()
        let data = try JSONSerialization.data(withJSONObject: [
            "booking_id": booking.uuidString, "context_revision": revision.uuidString,
            "evidence_context_version": 2, "service_at": "2026-09-01T12:00:00.123+00:00",
            "allowed_keys": [["dimension": "service", "value": "nail_trim"]]
        ])
        let context = try JSONDecoder().decode(BookingReviewContext.self, from: data)
        #expect(context.bookingID == booking)
        #expect(context.contextRevision == revision)
        #expect(context.signals.map(\.id) == ["service:nail_trim"])
        #expect(GroomingRequestDateFormatting.parsedDate(from: try #require(context.serviceAt)) != nil)
    }

    @Test(arguments: ["service:full_groom", "coat:wire", "size:Giant", "care:matted"])
    func canonicalKeysRoundTripThroughStoredOutcome(_ key: String) throws {
        let parts = key.split(separator: ":").map(String.init)
        let signal = try #require(ReviewEvidenceKey(dimension: parts[0], value: parts[1]).signal)
        #expect(PetFitSignal.stored(traitType: signal.traitType, traitValue: signal.traitValue) == signal)
    }

    @Test(arguments: ["coat:not_sure", "service:custom_request", "breed:poodle", "care:gentle_handling", "coat:Wire"])
    func unsupportedOrNoncanonicalKeysAreNotSelectable(_ key: String) {
        let parts = key.split(separator: ":").map(String.init)
        #expect(ReviewEvidenceKey(dimension: parts[0], value: parts[1]).signal == nil)
    }
}

@MainActor
private final class ReviewContextSession {
    var isCurrent = true
}
