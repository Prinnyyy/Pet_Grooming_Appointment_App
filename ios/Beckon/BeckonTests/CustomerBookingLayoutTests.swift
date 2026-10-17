import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class CustomerBookingLayoutTests: XCTestCase {
    func testOfferNameDoesNotCollapseToSingleLetterColumnAtAX3() async throws {
        let fixture = try await CustomerBookingUIFixture(screen: "offers")
        await fixture.requests.loadOffers(for: fixture.request)
        let offer = try XCTUnwrap(fixture.requests.offers(for: fixture.request).first)
        let host = UIHostingController(rootView: CustomerOfferSummaryRow(offerReview: offer, now: Date())
            .environment(\.dynamicTypeSize, .accessibility3))
        let size = host.sizeThatFits(in: CGSize(width: 350, height: 10_000))
        XCTAssertLessThan(size.height, 1_000, "One offer must not become a multi-screen column of letters")
        XCTAssertLessThanOrEqual(size.width, 351, "Allow pixel rounding, not horizontal overflow")
    }

    func testCachedReviewContextShowsTheSameOptionalFitChoicesAsFreshContext() async throws {
        let fresh = try await CustomerBookingUIFixture(screen: "review")
        let cached = try await CustomerBookingUIFixture(screen: "review")
        await cached.bookings.loadReviewContext(for: cached.booking)
        let freshHeight = try await reviewHeight(fresh)
        let cachedHeight = try await reviewHeight(cached)
        XCTAssertEqual(cachedHeight, freshHeight, accuracy: 1,
            "Reopening a review must not silently omit verified optional fit choices")
        XCTAssertEqual(cached.bookingRepository.reviewCallCount, 0)
        XCTAssertEqual(fresh.bookingRepository.reviewCallCount, 0)
    }

    private func reviewHeight(_ fixture: CustomerBookingUIFixture) async throws -> CGFloat {
        let host = UIHostingController(rootView: ReviewContent(fixture: fixture).frame(width: 350))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        try await Task.sleep(for: .milliseconds(300))
        return host.sizeThatFits(in: CGSize(width: 350, height: 10_000)).height
    }

    func testSubmittedReviewFixtureSurvivesItsAuthoritativeReload() async throws {
        let fixture = try await CustomerBookingUIFixture(screen: "review")
        await fixture.bookings.loadReviewContext(for: fixture.booking)
        await fixture.bookings.createReview(for: fixture.booking, rating: 4, content: "Patient handling and a tidy trim.")
        await fixture.bookings.load()
        XCTAssertEqual(fixture.bookingRepository.reviewCallCount, 1)
        XCTAssertEqual(fixture.bookings.booking(withID: fixture.booking.id)?.review?.rating, 4)
        XCTAssertNil(fixture.bookings.errorMessage)
    }

    private struct ReviewContent: View {
        let fixture: CustomerBookingUIFixture
        @FocusState private var focus: BookingReviewFocusTarget?
        var body: some View {
            BookingReviewForm(booking: fixture.booking, store: fixture.bookings,
                accent: .customer, focusedTarget: $focus)
        }
    }
}
