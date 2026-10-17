import Foundation
import Testing
@testable import Beckon

struct UIDisplayCopyTests {
    @Test func evidenceUsesSingularAndPluralCountsIndependently() {
        for (reviews, customers, expected) in [
            (0, 0, "0 related reviews from 0 customers"),
            (1, 1, "1 related review from 1 customer"),
            (2, 1, "2 related reviews from 1 customer"),
            (2, 2, "2 related reviews from 2 customers"),
        ] {
            let evidence = MatchingEvidence(state: "available", algorithmVersion: "matching-v1", scoreAsOf: nil,
                relatedReviewCount: reviews, independentCustomers: customers, completedCount: reviews,
                latestServiceAt: nil, coverage: [])
            #expect(evidence.summary == expected)
        }
    }

    @MainActor @Test func bookingFallbacksRemainHumanReadableWithoutInventingIdentity() {
        let booking = ServiceAgreementTests.booking()
        #expect(booking.displayTitle == "Grooming appointment")
        #expect(booking.participantSummary(for: .groomer) == "Customer")
        #expect(booking.partnerDisplayTitle(for: .customer) == "Grooming appointment")
        #expect(!booking.displayTitle.contains("ref"))
    }

    @MainActor @Test func requestTitleAndOfferSummaryKeepServiceContext() {
        let request = CustomerRequestsStoreTests.request(customerID: UUID(), petID: UUID(), status: .open)
        #expect(request.displayTitle == "\(request.serviceType.title) · \(request.petSnapshot.name)")
        let offer = CustomerRequestsStoreTests.offerReview(customerID: request.customerID, requestID: request.id)
        #expect(!offer.proposedTimeSummary.contains(offer.offer.proposedStart))
        #expect(offer.proposedTimeSummary.contains("Time zone not confirmed"))
    }
}
