import SwiftUI
import UIKit
import XCTest
import Testing
@testable import Beckon

@MainActor final class RefreshContinuityLayoutTests: XCTestCase {
    func testCountTilesKeepTheirHeightAcrossKnownUnknownAndRefreshStates() {
        for size: DynamicTypeSize in [.large, .accessibility3, .accessibility5] {
            var heights: [CGFloat] = []
            for (count, loading): (Int?, Bool) in [(12, false), (12, true), (nil, true), (nil, false)] {
                let host = UIHostingController(rootView: GroomerHomeTile(title: "Pending offers", systemImage: "tag.fill",
                    count: count, hasMore: false, isLoading: loading, identifier: "test.count", action: {})
                    .environment(\.dynamicTypeSize, size))
                heights.append(host.sizeThatFits(in: CGSize(width: 180, height: 10_000)).height)
            }
            XCTAssertLessThanOrEqual((heights.max() ?? 0) - (heights.min() ?? 0), 0.5, "Status changed tile height at \(size)")
        }
    }

    func testOrdinaryTabDepartureKeepsSettledContentVisible() async throws {
        let state = Activation()
        // Put the observable read in a View so a tab activation actually updates the environment.
        let root = UIHostingController(rootView: EntranceProbe(state: state))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 100)
        window.backgroundColor = .white
        window.rootViewController = root; window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        try await Task.sleep(for: .milliseconds(900))
        func darkPixels() -> Int {
            root.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            guard let data = image.cgImage?.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return 0 }
            return stride(from: 0, to: CFDataGetLength(data), by: 4).filter { bytes[$0] < 100 && bytes[$0+1] < 100 && bytes[$0+2] < 100 }.count
        }
        let settled = darkPixels()
        XCTAssertGreaterThan(settled, 100)
        state.active = false
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertGreaterThanOrEqual(darkPixels(), Int(Double(settled) * 0.9))
        state.active = true
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertGreaterThanOrEqual(darkPixels(), Int(Double(settled) * 0.9))
    }

    @Observable final class Activation { var active = true }
    struct EntranceProbe: View {
        let state: Activation
        var body: some View {
            Text("12 pending offers").font(.title).foregroundStyle(.black).padding().background(.white)
                .beckonEntrance(0).environment(\.beckonEntranceActive, state.active)
        }
    }
}

@MainActor struct RefreshReadinessTests {
    @Test func knownEmptyNotificationAndOfferListsStayKnownAfterRefreshFailure() async {
        let customerRepository = CustomerNotificationRepositoryFake()
        let customer = CustomerNotificationsStore(customerID: UUID(), repository: customerRepository)
        let groomerRepository = GroomerNotificationRepositoryFake()
        let groomer = GroomerNotificationsStore(groomerID: UUID(), repository: groomerRepository)
        let offerRepository = GroomerRequestRepositoryFake()
        let offers = GroomerOffersStore(groomerID: UUID(), repository: offerRepository)
        await customer.load(); await groomer.load(); await offers.load()
        #expect(customer.hasLoadedOnce && groomer.hasLoadedOnce && offers.hasLoadedOnce)
        #expect(customer.notifications.isEmpty && groomer.notifications.isEmpty && offers.offers.isEmpty)
        customerRepository.notificationsResult = .failure(.networkUnavailable)
        groomerRepository.notificationsResult = .failure(.networkUnavailable)
        offerRepository.offersResult = .failure(.networkUnavailable)
        await customer.load(); await groomer.load(); await offers.load()
        #expect(customer.hasLoadedOnce && groomer.hasLoadedOnce && offers.hasLoadedOnce)
    }
}
