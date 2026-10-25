import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class CustomerDialogPresentationTests: XCTestCase {
    func testStateDrivenCoverRendersContentAndCanReopen() async throws {
        let probe = Probe()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: StateDrivenDialog(probe: probe))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        try await wait { probe.open != nil }
        probe.open?()
        try await wait { probe.appearances == 1 }
        XCTAssertNotNil(host.presentedViewController)
        // onAppear fires before the entrance reaches a visible frame; capture the settled modal, not that first frame.
        try await Task.sleep(for: .milliseconds(600))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "T-420 state-driven production dialog"
        attachment.lifetime = .keepAlways
        add(attachment)
        probe.close?()
        try await wait { host.presentedViewController == nil }
        probe.open?()
        try await wait { probe.appearances == 2 }
        probe.close?()
        try await wait { host.presentedViewController == nil }
    }

    func testQuietOverlayClearsNoticeEvenWhenItDrawsNoToast() async throws {
        let center = BeckonFeedbackCenter()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: Color.white.overlay {
            BeckonGlobalFeedbackOverlay(center: center, isQuiet: true)
        })
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        center.showNotice("Request sent.")
        try await wait { center.notice == nil }
        XCTAssertNil(center.consumeAccessibilityAnnouncement(), "Quiet feedback must announce at most once")
    }

    private func wait(_ predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !predicate(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(predicate())
    }

    final class Probe {
        var open: (() -> Void)?
        var close: (() -> Void)?
        var appearances = 0
    }

    private struct StateDrivenDialog: View {
        let probe: Probe
        @State private var shows = false
        var body: some View {
            Text("Page behind the dialog")
                .designModal(isPresented: $shows) {
                    DesignModal(systemImage: "clock", title: "Propose a new time",
                        message: "Your current booking stays confirmed until both sides agree.",
                        actions: [.primary("Send proposal"), .quiet("Keep original time")]) {
                            Text("Your proposed appointment")
                                .onAppear { probe.appearances += 1 }
                        }
                }
                .onAppear {
                    probe.open = { shows = true }
                    probe.close = { shows = false }
                }
        }
    }
}
