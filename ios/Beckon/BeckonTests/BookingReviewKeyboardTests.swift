import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor final class BookingReviewKeyboardTests: XCTestCase {
    func testProductionReviewInputStaysAboveKeyboardAndDraftSurvivesDismissal() async throws {
        let booking = BookingsStoreTests.booking(status: .completed)
        let repository = BookingRepositoryFake(bookingsResult: .success([booking]))
        repository.reviewContextResult = .success(.init(bookingID: booking.id, contextRevision: UUID(),
            evidenceContextVersion: 2, serviceAt: nil, allowedKeys: []))
        let store = BookingsStore(participantID: booking.customerID, role: .customer, repository: repository, initialBookings: [booking])
        let draft = BookingReviewComposeDraft(rating: 4, content: "Please keep my words after closing.")
        store.updateReviewComposeDraft(draft, for: booking)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let probe = Probe()
        let observer = NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidShowNotification,
            object: nil, queue: .main) { notification in
            let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            MainActor.assumeIsolated { probe.frame = frame }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
            window.endEditing(true); window.isHidden = true; window.rootViewController = nil; previous?.makeKey()
        }
        let host = UIHostingController(rootView: BookingReviewSheet(booking: booking, store: store))
        window.rootViewController = host; window.makeKeyAndVisible()
        for _ in 0..<100 where input(in: window) == nil { try await Task.sleep(for: .milliseconds(10)) }
        let field = try XCTUnwrap(input(in: window))
        XCTAssertTrue(field.becomeFirstResponder())
        for _ in 0..<150 where probe.frame == nil { try await Task.sleep(for: .milliseconds(20)) }
        guard let frame = probe.frame else { throw XCTSkip("Simulator software keyboard unavailable") }
        try await Task.sleep(for: .milliseconds(200))
        window.layoutIfNeeded()
        let bounds = field.convert(field.bounds, to: window)
        XCTAssertLessThanOrEqual(bounds.maxY, window.convert(frame, from: nil).minY + 1)
        window.endEditing(true)
        window.rootViewController = UIViewController() // The composer leaves; its Store survives.
        XCTAssertEqual(store.reviewComposeDraft(for: booking.id), draft)
        window.rootViewController = UIHostingController(rootView: BookingReviewSheet(booking: booking, store: store))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(store.reviewComposeDraft(for: booking.id), draft)
        XCTAssertEqual(repository.reviewCallCount, 0)
    }
    private func input(in view: UIView) -> UIView? {
        if view is UITextView || view is UITextField { return view }
        return view.subviews.lazy.compactMap { self.input(in: $0) }.first
    }
    @MainActor private final class Probe { var frame: CGRect? }
}
