import Foundation
import Testing
@testable import Beckon

@MainActor
struct CustomerOfferHighlightTests {
    @Test func incompletePageNeverClaimsGlobalExtrema() {
        let reviews = offers()
        let highlights = CustomerOfferHighlights(reviews, isComplete: false)
        #expect(reviews.allSatisfy { highlights.badge(for: $0.id) == nil })
    }

    @Test func completeSetHighlightsPriceAndTimeWithoutGivingEveryOfferABadge() {
        let reviews = offers()
        let highlights = CustomerOfferHighlights(reviews, isComplete: true)
        #expect(highlights.badge(for: reviews[0].id) == .lowestPrice)
        #expect(highlights.badge(for: reviews[1].id) == .earliest)
        #expect(highlights.badge(for: reviews[2].id) == nil)
        #expect(CustomerOfferHighlights([reviews[0]], isComplete: true).badge(for: reviews[0].id) == nil)
    }

    private func offers() -> [CustomerOfferReview] {
        let customer = UUID(), request = UUID()
        return [
            CustomerRequestsStoreTests.offerReview(customerID: customer, requestID: request,
                price: 80, start: "2026-11-03T18:00:00Z"),
            CustomerRequestsStoreTests.offerReview(customerID: customer, requestID: request,
                price: 120, start: "2026-11-02T18:00:00Z"),
            CustomerRequestsStoreTests.offerReview(customerID: customer, requestID: request,
                price: 140, start: "2026-11-04T18:00:00Z"),
        ]
    }
}
