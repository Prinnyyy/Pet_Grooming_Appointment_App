import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class CustomerRequestWizardLayoutTests: XCTestCase {
    func testWizardHeaderRemainsVisibleWhenFormScrolls() async throws {
        let owner = UUID()
        let pets = (0..<8).map { _ in CustomerRequestsStoreTests.pet(customerID: owner) }
        let store = CustomerRequestsStore(customerID: owner,
            petRepository: CustomerRequestPetRepositoryFake(petsResult: .success(pets)),
            requestRepository: CustomerRequestRepositoryFake(),
            bookingRepository: CustomerRequestBookingRepositoryFake())
        await store.load()
        let host = UIHostingController(rootView: CustomerRequestWizardView(store: store))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        try await Task.sleep(for: .milliseconds(300))
        func scrolls(_ view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap(scrolls)
        }
        let scroll = try XCTUnwrap(scrolls(host.view).first { $0.contentSize.height > $0.bounds.height })
        let region = CGRect(x: 24, y: host.view.safeAreaInsets.top + 8, width: 280, height: 70)
        func headerPixels() throws -> Data {
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let crop = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(
                x: region.minX * image.scale, y: region.minY * image.scale,
                width: region.width * image.scale, height: region.height * image.scale)))
            return try XCTUnwrap(crop.dataProvider?.data) as Data
        }
        let before = try headerPixels()
        let oldOffset = scroll.contentOffset
        scroll.setContentOffset(CGPoint(x: 0, y: oldOffset.y + 180), animated: false)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertGreaterThan(scroll.contentOffset.y - oldOffset.y, 100)
        XCTAssertTrue(before == (try headerPixels()), "The progress band moved with the form")
    }

    func testLongPetSelectionDoesNotChangeCardGeometry() {
        let pet = CustomerPet(id: UUID(), customerID: UUID(),
            name: "Sir Bartholomew Wellington the Third",
            species: "Dog", breed: "Australian Shepherd / Standard Poodle Mix",
            coatType: nil, size: "L", weightLbs: 72.5, birthday: nil,
            temperament: nil, medicalNotes: nil, groomingNotes: nil, isActive: true)
        for width: CGFloat in [343, 398] {
            for size: DynamicTypeSize in [.large, .accessibility5] {
                let unselected = measure(pet: pet, selected: false, width: width, size: size)
                let selected = measure(pet: pet, selected: true, width: width, size: size)
                XCTAssertEqual(unselected.height, selected.height, accuracy: 1,
                    "Selection must not reflow text at width \(width), size \(size)")
                XCTAssertEqual(unselected.width, selected.width, accuracy: 1)
            }
        }
    }

    private func measure(pet: CustomerPet, selected: Bool, width: CGFloat,
                         size: DynamicTypeSize) -> CGSize {
        let host = UIHostingController(rootView: CustomerRequestPetChoiceCard(
            pet: pet, petPhotoData: nil, isSelected: selected, isInvalid: false, action: {})
            .environment(\.dynamicTypeSize, size))
        return host.sizeThatFits(in: CGSize(width: width, height: 10_000))
    }
}
