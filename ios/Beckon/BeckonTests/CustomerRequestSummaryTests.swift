import Foundation
import Testing
@testable import Beckon

@MainActor
struct CustomerRequestSummaryTests {
    @Test func allStatesHaveTruthfulProgressAndSharedSemantics() {
        let states: [(GroomingRequestStatus, Int?)] = [(.open, 1), (.hasOffers, 2), (.booked, 3),
            (.cancelled, nil), (.expired, nil), (.unknown, nil)]
        for (state, step) in states {
            let request = CustomerRequestsStoreTests.request(customerID: UUID(), petID: UUID(), status: state)
            let presentation = CustomerRequestSummaryPresentation(card: .init(request: request, handoff: nil))
            #expect(presentation.step == step)
            #expect(presentation.status.tone == state.presentation.tone)
            #expect(presentation.title == "Full groom · Mochi")
            #expect(presentation.accessibilityLabel.hasSuffix("Review"))
            #expect((presentation.progressSummary == nil) == (step == nil))
        }
    }

    @Test func loadedAndUnknownOfferCountsKeepPluralAndProgress() {
        let request = CustomerRequestsStoreTests.request(customerID: UUID(), petID: UUID(), status: .hasOffers)
        for (count, title): (Int?, String) in [(nil, "Offers ready to review"), (0, "0 offers to review"),
            (1, "1 offer to review"), (2, "2 offers to review")] {
            let presentation = CustomerRequestSummaryPresentation(card: .init(request: request, handoff: nil,
                loadedOfferCount: count))
            #expect(presentation.status.title == title)
            #expect(presentation.status.systemImage == "tag")
            #expect(presentation.progressSummary == "Step 2 of 3: offers received")
        }
    }

    @Test func confirmedHandoffUsesBookingTimeAndCompletedProgress() async throws {
        let fixture = try await CustomerBookingUIFixture(screen: "booking")
        let presentation = CustomerRequestSummaryPresentation(card: .init(request: fixture.request,
            handoff: .init(request: fixture.request, booking: fixture.booking)))
        #expect(presentation.step == 3)
        #expect(presentation.status == GroomingRequestStatus.booked.presentation)
        #expect(presentation.time == fixture.booking.scheduledTimePresentation)
    }

    @Test func countsUseOnlyCompleteLoadedPagesAndNeverFetch() async throws {
        let fixture = try await CustomerBookingUIFixture(screen: "offers")
        let store = fixture.requests
        #expect(store.loadedCurrentOfferCount(for: fixture.request) == nil)
        let before = fixture.requestRepository.rankedRequests.count
        _ = store.visibleActionCards
        #expect(fixture.requestRepository.rankedRequests.count == before)
        await store.loadOffers(for: fixture.request)
        #expect(store.loadedCurrentOfferCount(for: fixture.request) == 2)
        #expect(store.loadedCurrentOfferCount(for: fixture.request, now: Date().addingTimeInterval(86400 * 3)) == 0)
        let reviews = store.offers(for: fixture.request)
        fixture.requestRepository.rankedPages = [.success(RankedPage(items: reviews, rankingRevision: "partial",
            scoreAsOf: .now, validUntil: .now.addingTimeInterval(300), algorithmVersion: "matching-v1",
            requestedMode: "balanced", effectiveMode: "balanced", pendingCount: 0, assessmentCount: 0, nextCursor: "more"))]
        await store.loadOffers(for: fixture.request)
        #expect(store.loadedCurrentOfferCount(for: fixture.request) == nil)
        let reads = fixture.requestRepository.rankedRequests.count
        _ = store.visibleActionCards
        #expect(fixture.requestRepository.rankedRequests.count == reads)
    }
}
