import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class ChatBackNavigationTests: XCTestCase {
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
        for _ in 0..<20 {
            await Task.yield()
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
