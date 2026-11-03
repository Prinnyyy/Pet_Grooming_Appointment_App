import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class ChatBackNavigationTests: XCTestCase {
    func testGuardedEditorUsesTheSameNativePopWithoutDiscardingUnsavedEdits() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let navigation = UINavigationController(rootViewController: UIViewController())
        let window = UIWindow(windowScene: scene)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        let guardState = BackGuardProbe()
        let editor = UIHostingController(rootView: Text("Availability").beckonAllowsInteractiveBack {
            guardState.attempts += 1
            return !guardState.hasEdits && !guardState.isSaving
        })
        navigation.pushViewController(editor, animated: false)
        for _ in 0..<50 where !(navigation.interactivePopGestureRecognizer?.delegate is BeckonInteractiveBackBridge.Controller) {
            try await Task.sleep(for: .milliseconds(10))
            editor.view.layoutIfNeeded()
        }
        let gesture = try XCTUnwrap(navigation.interactivePopGestureRecognizer)
        let delegate = try XCTUnwrap(gesture.delegate)
        XCTAssertTrue(delegate is BeckonInteractiveBackBridge.Controller)
        XCTAssertEqual(delegate.gestureRecognizerShouldBegin?(gesture), true)
        guardState.hasEdits = true
        XCTAssertEqual(delegate.gestureRecognizerShouldBegin?(gesture), false)
        XCTAssertEqual(navigation.viewControllers.count, 2)
        guardState.hasEdits = false; guardState.isSaving = true
        XCTAssertEqual(delegate.gestureRecognizerShouldBegin?(gesture), false)
        XCTAssertEqual(guardState.attempts, 3)
    }
    private final class BackGuardProbe { var hasEdits = false; var isSaving = false; var attempts = 0 }

    func testHiddenHeaderKeepsNativePopAndRestoresThePreviousDelegate() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let root = UIViewController()
        let navigation = UINavigationController(rootViewController: root)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        let gesture = try XCTUnwrap(navigation.interactivePopGestureRecognizer)
        let previousDelegate = gesture.delegate
        let chat = UIHostingController(rootView: Text("Chat").beckonAllowsInteractiveBack())
        navigation.setNavigationBarHidden(true, animated: false)
        navigation.pushViewController(chat, animated: false)
        for _ in 0..<50 where !(gesture.delegate is BeckonInteractiveBackBridge.Controller) {
            try await Task.sleep(for: .milliseconds(10))
            chat.view.layoutIfNeeded()
        }
        let delegate = try XCTUnwrap(gesture.delegate)
        XCTAssertTrue(delegate is BeckonInteractiveBackBridge.Controller)
        XCTAssertTrue(gesture.isEnabled)
        XCTAssertEqual(delegate.gestureRecognizerShouldBegin?(gesture), true)
        navigation.popViewController(animated: false)
        for _ in 0..<100 where gesture.delegate !== previousDelegate {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(gesture.delegate === previousDelegate, "After pop: \(String(describing: gesture.delegate)), original: \(String(describing: previousDelegate))")
        XCTAssertEqual(navigation.viewControllers.count, 1)
    }
}
