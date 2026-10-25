import Foundation
import Testing
@testable import Beckon

@MainActor
struct GroomerSelectionTests {
    @Test func selectingSixthGroomerKeepsFiveAndDeselectingFreesASlot() {
        var selection = GroomerSelection()
        let ids = (0..<6).map { _ in UUID() }
        for id in ids { selection.toggle(id, name: id.uuidString) }
        #expect(selection.count == 5)
        #expect(!selection.contains(ids[5]))
        selection.toggle(ids[0], name: "First")
        selection.toggle(ids[5], name: "Sixth")
        #expect(selection.count == 5)
        #expect(selection.contains(ids[5]))
        selection.keep([])
        #expect(selection.isEmpty)
    }

    @Test func offeredButUnselectableQuoteDoesNotConsumeASlot() {
        var first = CustomerRequestsStoreTests.offerReview(customerID: UUID(), requestID: UUID()).offer
        first.quoteEvaluation = QuoteEvaluation(termsValid: true, selectable: false, reason: "time_unavailable")
        let review = CustomerOfferReview(offer: first, groomerProfile: nil)
        let progress = progress(invited: first.groomerID)
        let capacity = GroomerInvitationCapacity(progress: progress, offers: [review], completeOffers: true, now: now)
        #expect(capacity.remaining == 5)
        first.quoteEvaluation = QuoteEvaluation(termsValid: true, selectable: true, reason: "available")
        let available = GroomerInvitationCapacity(progress: progress,
            offers: [CustomerOfferReview(offer: first, groomerProfile: nil)], completeOffers: true, now: now)
        #expect(available.remaining == 4)
    }

    @Test func partialOfferPageDoesNotDeclareOfferedSlotsFull() {
        let capacity = GroomerInvitationCapacity(progress: progress(invited: UUID()), offers: [],
            completeOffers: false, now: now)
        #expect(capacity.remaining == nil)
        #expect(capacity.selectionLimit == 5)
    }

    private var now: Date { ISO8601DateFormatter().date(from: "2026-06-20T10:00:00Z")! }

    private func progress(invited: UUID) -> CustomerRequestProgress {
        CustomerRequestProgress(requestID: UUID(), termsRevision: UUID(), distributionRevision: UUID(),
            poolEnabled: false, status: .hasOffers, expiresAt: now.addingTimeInterval(86_400), checkedAt: now,
            evaluationPending: false, validOfferCount: 0, invitations: [
                RequestInvitation(groomerID: invited, profile: nil, sentAt: now,
                    replyBy: now.addingTimeInterval(3_600), state: .offered),
            ])
    }
}
