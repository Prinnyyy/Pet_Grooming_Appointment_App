import Foundation
import Testing
@testable import Beckon

struct BeckonStatusPresentationTests {
    @MainActor @Test func evaluatedOffersPreserveDeadlineAndCapacityStates() throws {
        var offer = CustomerRequestsStoreTests.offerReview(customerID: UUID(), requestID: UUID()).offer
        offer.agreementSnapshotLoaded = true
        let expiry = try #require(GroomingRequestDateFormatting.parsedDate(from: offer.expiresAt))
        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: offer.proposedStart))
        let cutoff = min(expiry, start.addingTimeInterval(-300))
        let now = cutoff.addingTimeInterval(-1)
        #expect(offer.statusPresentation(now: now) == .init(title: "Checking", systemImage: "clock", tone: .info))
        for (json, state) in [
            (#"{"terms_valid":true,"selectable":false,"reason":"capacity_unavailable"}"#, GroomerOfferDisplayStatus.timeUnavailable),
            (#"{"terms_valid":false,"selectable":false,"reason":"terms_changed"}"#, .newOfferRequired),
            (#"{"terms_valid":false,"selectable":false,"reason":"expired"}"#, .status(.expired)),
            (#"{"terms_valid":true,"selectable":true,"reason":"available"}"#, .status(.pending)),
        ] {
            offer.quoteEvaluation = try JSONDecoder().decode(QuoteEvaluation.self, from: Data(json.utf8))
            #expect(offer.evaluatedDisplayStatus(now: now) == state)
            #expect(offer.statusPresentation(now: now) == state.presentation)
            #expect(offer.evaluatedStatusTitle(now: now) == state.presentation.title)
            #expect(offer.statusPresentation(now: cutoff) == GroomerOfferStatus.expired.presentation)
        }
        let accepted = offer.replacing(status: .acceptedByCustomer, withdrawnAt: nil)
        #expect(accepted.statusPresentation(now: cutoff) == GroomerOfferStatus.acceptedByCustomer.presentation)
    }

    @Test func allGroomingRequestStatusCases() {
        let expected: [GroomingRequestStatus: BeckonStatusPresentation] = [
            .open: .init(title: "Open", systemImage: "clock", tone: .info),
            .hasOffers: .init(title: "Has offers", systemImage: "tag", tone: .warning),
            .booked: .init(title: "Booked", systemImage: "checkmark.circle", tone: .success),
            .cancelled: .init(title: "Cancelled", systemImage: "xmark.circle", tone: .neutral),
            .expired: .init(title: "Expired", systemImage: "hourglass", tone: .neutral),
            .unknown: .init(title: "Unknown", systemImage: "questionmark.circle", tone: .neutral),
        ]
        #expect(expected.count == GroomingRequestStatus.allCases.count)
        for status in GroomingRequestStatus.allCases {
            #expect(status.presentation == expected[status])
        }
    }

    @Test func allRequestMatchStatusCases() {
        let expected: [RequestMatchStatus: BeckonStatusPresentation] = [
            .visible: .init(title: "New", systemImage: "sparkles", tone: .info),
            .viewed: .init(title: "Viewed", systemImage: "sparkles", tone: .info),
            .offered: .init(title: "Offer sent", systemImage: "clock", tone: .warning),
            .dismissed: .init(title: "Dismissed", systemImage: "xmark.circle", tone: .neutral),
            .hidden: .init(title: "Hidden", systemImage: "minus.circle", tone: .neutral),
            .expired: .init(title: "Expired", systemImage: "hourglass", tone: .neutral),
            .unknown: .init(title: "Unknown", systemImage: "questionmark.circle", tone: .neutral),
        ]
        #expect(expected.count == RequestMatchStatus.allCases.count)
        for status in RequestMatchStatus.allCases {
            #expect(status.presentation == expected[status])
        }
    }

    @Test func allGroomerOfferStatusCases() {
        let expected: [GroomerOfferStatus: BeckonStatusPresentation] = [
            .pending: .init(title: "Pending", systemImage: "clock", tone: .warning),
            .acceptedByCustomer: .init(title: "Accepted", systemImage: "checkmark.circle", tone: .success),
            .declinedByCustomer: .init(title: "Declined", systemImage: "xmark.circle", tone: .neutral),
            .withdrawnByGroomer: .init(title: "Withdrawn", systemImage: "arrow.uturn.backward", tone: .neutral),
            .expired: .init(title: "Expired", systemImage: "hourglass", tone: .neutral),
            .unknown: .init(title: "Unknown", systemImage: "questionmark.circle", tone: .neutral),
        ]
        #expect(expected.count == GroomerOfferStatus.allCases.count)
        for status in GroomerOfferStatus.allCases {
            #expect(status.presentation == expected[status])
        }
    }

    @Test func allBookingStatusCases() {
        let expected: [BookingStatus: BeckonStatusPresentation] = [
            .confirmed: .init(title: "Confirmed", systemImage: "calendar.badge.checkmark", tone: .info),
            .completed: .init(title: "Completed", systemImage: "checkmark.circle", tone: .success),
            .unfulfilled: .init(title: "Service not confirmed", systemImage: "minus.circle", tone: .neutral),
            .cancelledByCustomer: .init(title: "Cancelled by customer", systemImage: "xmark.circle", tone: .neutral),
            .cancelledByGroomer: .init(title: "Cancelled by groomer", systemImage: "xmark.circle", tone: .neutral),
            .unknown: .init(title: "Unknown", systemImage: "questionmark.circle", tone: .neutral),
        ]
        #expect(expected.count == BookingStatus.allCases.count)
        for status in BookingStatus.allCases {
            #expect(status.presentation == expected[status])
        }
    }
}
