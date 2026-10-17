import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class GroomerWorkspaceLayoutTests: XCTestCase {
    func testPhotoEditorActionUsesFullWidthAtAX3() async throws {
        var previewFrame = CGRect.zero
        var actionFrame = CGRect.zero
        let host = UIHostingController(rootView: BeckonPhotoEditorCard(
            title: "Profile Photo", statusText: "Photo saved to your profile.",
            showsSavedIndicator: true, savedAccessibilityLabel: "Profile photo saved") {
                Color.clear.frame(width: 96, height: 96)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { previewFrame = $0 }
            } action: {
                Button("Replace Photo", systemImage: "camera") {}
                    .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer))
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { actionFrame = $0 }
            }
            .frame(width: 350)
            .environment(\.dynamicTypeSize, .accessibility3))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(actionFrame.minX, previewFrame.minX, accuracy: 1)
        XCTAssertGreaterThan(actionFrame.width, 280)
        XCTAssertGreaterThan(actionFrame.minY, previewFrame.maxY)
    }

    func testAvailabilityTimeControlsGrowWithoutShrinkingTheirText() {
        for size: DynamicTypeSize in [.large, .accessibility3] {
            let host = UIHostingController(rootView: GroomerAvailabilityTimeMenu(
                minutes: .constant(17 * 60), title: "End", day: "Wednesday")
                .environment(\.dynamicTypeSize, size))
            let measured = host.sizeThatFits(in: CGSize(width: 150, height: 10_000))
            XCTAssertGreaterThanOrEqual(measured.height, 44)
            XCTAssertLessThanOrEqual(measured.width, 150)
            if size.isAccessibilitySize { XCTAssertGreaterThan(measured.height, 65) }
        }
    }

    func testAvailabilityBufferFocusRemainsResponsiveAtAX3() async throws {
        let owner = UUID()
        let store = GroomerProfileStore(groomerID: owner, repository: GroomerProfileRepositoryFake(
            profileResult: .success(GroomerProfileStoreTests.profile(groomerID: owner)),
            availabilityResult: .success([GroomerProfileStoreTests.availability(groomerID: owner)])))
        await store.load()
        let host = UIHostingController(rootView: NavigationStack {
            GroomerAvailabilityEditorView(store: store)
        }.environment(\.dynamicTypeSize, .accessibility3))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        try await Task.sleep(for: .milliseconds(300))
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
        let field = try XCTUnwrap(descendants(host.view).compactMap { $0 as? UITextField }.last)
        XCTAssertTrue(field.becomeFirstResponder())
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(field.isFirstResponder)
        let frame = field.convert(field.bounds, to: window)
        XCTAssertGreaterThanOrEqual(frame.minY, window.safeAreaInsets.top)
        XCTAssertLessThanOrEqual(frame.maxY, window.bounds.height)
        field.resignFirstResponder()
    }

    func testSectionAccessoryReflowsBelowHeadingAtAccessibilitySize() async throws {
        var accessoryFrame = CGRect.zero
        let host = UIHostingController(rootView: BeckonSectionHeading(
            title: "Weekly Hours", subtitle: "Set the recurring hours when you can accept appointments.") {
                Text("1 day open")
                    .font(DesignTokens.Typography.status)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { accessoryFrame = $0 }
            }
            .padding(20)
            .frame(width: 350, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
            .environment(\.dynamicTypeSize, .accessibility3))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        try await Task.sleep(for: .milliseconds(300))
        let leading = (window.bounds.width - 350) / 2 + 20
        XCTAssertGreaterThan(accessoryFrame.height, 0)
        XCTAssertEqual(accessoryFrame.minX, leading, accuracy: 1,
            "The summary must use its own row, not squeeze the heading into a narrow column")
    }
}
