import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor final class GroomerModuleRenderingTests: XCTestCase {
    func testAdoptedModuleStatesRenderWithLocalDependencies() async throws {
        var samples: [(String, AnyView)] = []
        for tab in GroomerTab.allCases {
            for state: GroomerSandboxState in [.loaded, .empty, .loading] {
                samples.append(("\(tab) / \(state)", AnyView(GroomerFlowSandbox(state: state, startsOn: tab))))
            }
        }
        samples.append(("Busy agenda", AnyView(GroomerFlowSandbox(state: .busyDay, startsOn: .bookings))))
        samples.append(("Busy Home", AnyView(GroomerFlowSandbox(state: .busyDay))))
        samples.append(("Paused Home", AnyView(GroomerHomePagePreview(requestsPaused: true))))
        for (label, route) in [
            ("Mochi make offer", GroomerRequestsRoute(segment: .matches, requestID: GroomerSandboxFixtures.id(201), offerID: nil)),
            ("Rocky confirm size", GroomerRequestsRoute(segment: .matches, requestID: GroomerSandboxFixtures.id(204), offerID: nil)),
            ("Pepper pending", GroomerRequestsRoute(segment: .matches, requestID: GroomerSandboxFixtures.id(205), offerID: nil)),
            ("Bella booked", GroomerRequestsRoute(segment: .offers, requestID: nil, offerID: GroomerSandboxFixtures.id(502))),
            ("Milo declined", GroomerRequestsRoute(segment: .offers, requestID: nil, offerID: GroomerSandboxFixtures.id(503))),
        ] {
            samples.append((label, AnyView(GroomerFlowSandbox(startsOn: .requests, route: route))))
        }
        samples.append(("Offers loading", AnyView(GroomerFlowSandbox(state: .loading, startsOn: .requests, route: .offers))))
        samples.append(("Unanswered checking", AnyView(GroomerRequestMoment.checking.list(.matches))))
        samples.append(("No unanswered matches", AnyView(GroomerRequestMoment.timingMissing.list(.matches))))
        samples.append(("Schedule phases", AnyView(GroomerScheduleMoments())))
        samples.append(("Booked Bella", AnyView(GroomerPageHost { session in
            BookingDetailView(bookingID: GroomerSandboxFixtures.id(603), role: .groomer, store: session.bookings)
        })))
        samples.append(("Under way Rosie", AnyView(GroomerPageHost(state: .busyDay) { session in
            BookingDetailView(bookingID: GroomerSandboxFixtures.id(607), role: .groomer, store: session.bookings)
        })))
        samples.append(("Notifications", AnyView(GroomerPageHost { session in
            GroomerNotificationsView(store: session.notifications, requestStore: session.requests,
                bookingStore: session.bookings, chatStore: session.chat)
        })))
        samples.append(("Thread", AnyView(GroomerPageHost { GroomerThreadPreview(session: $0) })))
        samples.append(("Long matches", AnyView(GroomerPageHost(matches: GroomerSandboxFixtures.stressMatches(), prepare: {
            await $0.requests.load(); await $0.offers.load()
        }) { session in GroomerRequestsView(route: .constant(.matches), requests: session.requests, offers: session.offers) })))
        for moment in GroomerBookingMoment.allCases { samples.append(("Booking \(moment)", AnyView(moment.preview))) }
        for moment in GroomerRequestMoment.allCases {
            samples.append(("Request \(moment)", AnyView(moment.preview)))
            samples.append(("Offers \(moment)", AnyView(moment.list(.offers))))
        }
        for state: GroomerSandboxState in [.loaded, .empty] {
            samples += [
                ("Profile \(state)", AnyView(GroomerAccountPageHost(state: state) { GroomerProfileEditorView(store: $0) })),
                ("Services \(state)", AnyView(GroomerAccountPageHost(state: state) { GroomerServicesEditorView(store: $0) })),
                ("Availability \(state)", AnyView(GroomerAccountPageHost(state: state) { GroomerAvailabilityEditorView(store: $0) })),
                ("Portfolio \(state)", AnyView(GroomerAccountPageHost(state: state) { GroomerPortfolioEditorView(store: $0) })),
                ("Fit \(state)", AnyView(GroomerAccountPageHost(state: state) { GroomerFitSignalsEditorView(store: $0) })),
                ("Evidence \(state)", AnyView(GroomerAccountPageHost(state: state) { GroomerEvidenceDashboardView(store: $0) })),
            ]
        }
        samples.append(("Full fit slots", AnyView(GroomerAccountPageHost(state: .slotsFull) { GroomerFitSignalsEditorView(store: $0) })))
        samples.append(("Portfolio photo", AnyView(GroomerAccountPageHost { store in
            if let photo = store.sortedPortfolioPhotos().first { GroomerPortfolioPhotoView(photo: photo, store: store) }
        })))
        samples.append(("Service sheet", AnyView(GroomerAccountPageHost(opens: { $0.startCreateService() }) { GroomerServiceFormView(store: $0) })))
        samples.append(("Booking message states", AnyView(ScrollView { ChatBookingCardStates() })))
        for role: UserRole? in [nil, .customer, .groomer] {
            samples.append(("Setup \(String(describing: role))", AnyView(AppFlowSandbox(screen: .onboarding, role: role))))
        }
        let axSamples: [(String, AnyView)] = [
            ("AX Max Requests", AnyView(GroomerFlowSandbox(startsOn: .requests))),
            ("AX Max fit", AnyView(GroomerAccountPageHost(state: .slotsFull) { GroomerFitSignalsEditorView(store: $0) })),
            ("AX Requests", AnyView(GroomerFlowSandbox(startsOn: .requests))),
            ("AX busy agenda", AnyView(GroomerFlowSandbox(state: .busyDay, startsOn: .bookings))),
            ("AX reported booking", AnyView(GroomerBookingMoment.reportedByCustomer.preview)),
            ("AX full fit", AnyView(GroomerAccountPageHost(state: .slotsFull) { GroomerFitSignalsEditorView(store: $0) })),
            ("AX service sheet", AnyView(GroomerAccountPageHost(opens: { $0.startCreateService() }) { GroomerServiceFormView(store: $0) })),
        ]
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        for (label, view) in samples + axSamples {
            let host = UIHostingController(rootView: view.environment(\.scenePhase, .active)
                .environment(\.dynamicTypeSize, label.hasPrefix("AX Max ") ? .accessibility5 : (label.hasPrefix("AX ") ? .accessibility3 : .large)))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            try await Task.sleep(for: .milliseconds(400))
            host.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let pixels = try XCTUnwrap(image.cgImage?.dataProvider?.data, label)
            let bytes = try XCTUnwrap(CFDataGetBytePtr(pixels), label)
            XCTAssertGreaterThan(Set(stride(from: 0, to: CFDataGetLength(pixels), by: 64).map { bytes[$0] }).count, 8,
                "Blank module state: \(label)")
        }
        print("T436 rendered \(samples.count + axSamples.count) local module/state/size combinations; first-viewport smoke, not visual equivalence.")
    }
}
