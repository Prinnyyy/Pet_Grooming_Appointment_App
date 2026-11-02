import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class RoleKitTests: XCTestCase {
    func testAccentResolvesFromRoleWithoutChangingCustomerPalette() {
        typealias C = DesignTokens.Colors
        typealias H = DesignTokens.ColorHex
        let pairs: [(Color, UInt, UInt)] = [
            (C.customerFill, H.customerFill, H.groomerFill),
            (C.customerFillPressed, H.customerFillPressed, H.groomerFillPressed),
            (C.customerInk, H.customerInk, H.groomerInk),
            (C.customerDeep, H.customerDeep, H.groomerDeep),
            (C.customerTint, H.customerTint, H.groomerTint),
            (C.customerHeroEnd, H.customerHeroEnd, H.groomerHeroEnd),
            (C.customerHeroBubble, H.customerHeroBubble, H.groomerHeroBubble),
            (C.customerHeroDecoration, H.customerHeroDecoration, H.groomerHeroDecoration),
            (C.skeleton, H.customerTint, H.groomerTint),
            (C.skeletonOnPage, H.customerHeroBubble, H.groomerHeroBubble),
            (C.sceneSkyTop, H.sceneSkyTop, H.groomerSceneSkyTop),
            (C.sceneSkyHorizon, H.sceneSkyHorizon, H.groomerSceneSkyHorizon),
            (C.sceneMountainFar, H.sceneMountainFar, H.groomerSceneMountainFar),
            (C.sceneMountainNear, H.sceneMountainNear, H.groomerSceneMountainNear),
            (C.sceneLawn, H.sceneLawn, H.groomerSceneLawn),
        ]
        for (color, customer, groomer) in pairs {
            for (role, expected) in [(BeckonRole.customer, customer), (.groomer, groomer)] {
                let traits = UITraitCollection { $0.beckonRole = role }
                assertColor(UIColor(color).resolvedColor(with: traits), hex: expected)
            }
        }
    }

    func testRoleTravelsIntoPresentedSheetAndDoesNotLeakToPresenter() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let probe = SheetProbe()
        let host = UIHostingController(rootView: SheetPage(probe: probe))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        try await wait { probe.open != nil }
        probe.open?()
        try await wait { host.presentedViewController?.traitCollection.beckonRole == .groomer && probe.role == .groomer }
        XCTAssertEqual(host.traitCollection.beckonRole, .customer)
        let sheet = try XCTUnwrap(host.presentedViewController)
        assertColor(UIColor(DesignTokens.Colors.customerFill).resolvedColor(with: sheet.traitCollection),
            hex: DesignTokens.ColorHex.groomerFill)
        probe.close?()
        try await wait { host.presentedViewController == nil && probe.dismissCount == 1 }
        XCTAssertEqual(host.traitCollection.beckonRole, .customer)
    }

    func testActionsAndLoadMoreKeepTheirHeightAcrossStatesAndRoles() {
        for role in [BeckonRole.customer, .groomer] {
            let accent: BeckonSecondaryButtonStyle.Accent = role == .groomer ? .groomer : .customer
            for size in [DynamicTypeSize.large, .accessibility3] {
                let main = height(GroomingActionButton(title: "Continue", systemImage: "checkmark",
                    identifier: "main") {}, role: role, size: size)
                let quiet = height(GroomingActionButton(title: "Continue", systemImage: "checkmark", style: .secondary,
                    identifier: "quiet") {}, role: role, size: size)
                XCTAssertEqual(main, quiet, accuracy: 0.5)
                let ready = height(BeckonLoadMoreButton(isLoading: false, accent: accent,
                    accessibilityIdentifier: "more") {}, role: role, size: size)
                let failed = height(BeckonLoadMoreButton(isLoading: false, accent: accent,
                    accessibilityIdentifier: "more", failed: true) {}, role: role, size: size)
                let loading = height(BeckonLoadMoreButton(isLoading: true, accent: accent,
                    accessibilityIdentifier: "more", failed: true) {}, role: role, size: size)
                XCTAssertEqual(ready, failed, accuracy: 0.5)
                XCTAssertEqual(ready, loading, accuracy: 0.5)
                let chosen = height(DesignChoiceChip(title: "Matches", isSelected: true) {}, role: role, size: size)
                let unchosen = height(DesignChoiceChip(title: "Matches", isSelected: false) {}, role: role, size: size)
                XCTAssertEqual(chosen, unchosen, accuracy: 0.5)
            }
        }
    }

    func testWhenComponentsKeepAuthoritativeTimezoneRequirement() throws {
        let start = "2026-11-01T18:30:00Z"
        let when = try XCTUnwrap(BeckonWhen(start: start, end: nil, zoneIdentifier: "America/Los_Angeles"))
        XCTAssertEqual(when.short, "\(when.day) · \(when.start)")
        XCTAssertEqual(when.start, "10:30 AM")
        XCTAssertNil(BeckonWhen(start: start, end: nil, zoneIdentifier: nil))
        XCTAssertNil(BeckonWhen(start: start, end: nil, zoneIdentifier: "invalid"))
    }

    private func height(_ view: some View, role: BeckonRole, size: DynamicTypeSize) -> CGFloat {
        UIHostingController(rootView: view.environment(\.beckonCustomerDesign, true)
            .environment(\.beckonRole, role).environment(\.dynamicTypeSize, size))
            .sizeThatFits(in: CGSize(width: 343, height: 10_000)).height
    }

    private func assertColor(_ color: UIColor, hex: UInt, file: StaticString = #filePath, line: UInt = #line) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&r, green: &g, blue: &b, alpha: &alpha), file: file, line: line)
        XCTAssertEqual(r, CGFloat((hex >> 16) & 255) / 255, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(g, CGFloat((hex >> 8) & 255) / 255, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(b, CGFloat(hex & 255) / 255, accuracy: 0.001, file: file, line: line)
    }

    private func wait(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(condition(), file: file, line: line)
    }

    private final class SheetProbe {
        var open: (() -> Void)?
        var close: (() -> Void)?
        var role: BeckonRole?
        var dismissCount = 0
    }

    private struct SheetPage: View {
        let probe: SheetProbe
        @State private var shows = false
        var body: some View {
            Text("Presenter")
                .beckonSheet(isPresented: $shows, onDismiss: { probe.dismissCount += 1 }) {
                    RoleReadout(probe: probe).onAppear { probe.close = { shows = false } }
                }
                .environment(\.beckonRole, .groomer)
                .onAppear { probe.open = { shows = true } }
        }
    }

    private struct RoleReadout: View {
        let probe: SheetProbe
        @Environment(\.beckonRole) private var role
        var body: some View { Text("Sheet").onChange(of: role, initial: true) { _, current in probe.role = current } }
    }
}
