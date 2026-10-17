import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class UIColorImplementationSnapshotTests: XCTestCase {
    func testRoleHomes() async throws {
        let customer = try await CustomerBookingUIFixture(screen: "booking")
        let pet = CustomerRequestsStoreTests.pet(customerID: customer.request.customerID)
        for largeText in [false, true] {
            try await capture(CustomerTabView(
                customerID: customer.request.customerID,
                customerDisplayName: "Alexandra",
                petRepository: CustomerRequestPetRepositoryFake(petsResult: .success([pet])),
                requestRepository: customer.requestRepository,
                notificationRepository: CustomerNotificationRepositoryFake(),
                bookingRepository: customer.bookingRepository
            ), name: "customer-home", largeText: largeText)
            let groomer = GroomerUIFixture()
            try await capture(GroomerTabView(
                groomerID: groomer.owner, groomerDisplayName: "Alexandra Wellington",
                profileRepository: groomer.profile, requestRepository: groomer.requests,
                notificationRepository: groomer.notifications, bookingRepository: groomer.bookings,
                chatRepository: groomer.chat, onSignOut: {}
            ), name: "groomer-home", largeText: largeText)
            XCTAssertEqual(groomer.requests.createOfferCallCount, 0)
            XCTAssertEqual(groomer.profile.saveAvailabilityCallCount, 0)
        }
    }

    private func capture<Content: View>(_ content: Content, name: String, largeText: Bool) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let visible = scene.windows.filter { !$0.isHidden }
        visible.forEach { $0.isHidden = true }
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = UIHostingController(rootView: content
            .environment(\.dynamicTypeSize, largeText ? .accessibility3 : .large))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            visible.forEach { $0.isHidden = false }
            previous?.makeKey()
        }
        try await Task.sleep(for: .milliseconds(600))
        window.layoutIfNeeded()
        XCTAssertGreaterThan(window.bounds.width, 300)
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "UI-color-\(name)-\(largeText ? "AX3" : "default")"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
