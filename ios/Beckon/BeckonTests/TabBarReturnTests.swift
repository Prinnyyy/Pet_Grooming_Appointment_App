import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor final class TabBarReturnTests: XCTestCase {
    func testCompletedAndCancelledReturnsKeepTheBarHiddenUntilCompletion() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let root = UIViewController()
        let navigation = UINavigationController(rootViewController: root)
        let tabs = UITabBarController()
        tabs.viewControllers = [navigation]
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        let slot = BeckonTabBarSlot()
        slot.controller = tabs
        slot.owner = navigation
        func page() -> UIViewController {
            UIHostingController(rootView: Color.white.beckonHidesTabBar().environment(\.beckonTabBarSlot, slot))
        }
        navigation.pushViewController(page(), animated: false)
        await settle()
        XCTAssertTrue(tabs.isTabBarHidden)
        navigation.pushViewController(page(), animated: false)
        await settle()
        navigation.popViewController(animated: false)
        await settle()
        XCTAssertTrue(tabs.isTabBarHidden, "Returning to another hidden destination must keep the bar hidden")

        let driver = PopDriver()
        navigation.delegate = driver
        driver.interaction = UIPercentDrivenInteractiveTransition()
        navigation.popViewController(animated: true)
        driver.interaction?.update(0.3)
        XCTAssertTrue(tabs.isTabBarHidden, "Starting an edge-back interaction must not reveal the bar")
        driver.interaction?.cancel()
        await finish(navigation)
        await settle()
        XCTAssertTrue(tabs.isTabBarHidden, "Cancelling must keep the detail and bar state")
        XCTAssertEqual(navigation.viewControllers.count, 2)

        driver.interaction = nil
        navigation.popViewController(animated: true)
        XCTAssertTrue(tabs.isTabBarHidden, "The bar stays hidden throughout a completed return")
        await finish(navigation)
        await settle()
        XCTAssertFalse(tabs.isTabBarHidden)
        XCTAssertEqual(navigation.viewControllers.count, 1)
    }

    func testSwiftUIShellOwnsVisibilityAcrossPushAndReturn() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let route = Route()
        window.rootViewController = UIHostingController(rootView: TabView {
            BeckonTabBarOwner {
                NavigationStack(path: Bindable(route).path) {
                    Text("Root").navigationDestination(for: Int.self) { _ in
                        Text("Detail").beckonHidesTabBar()
                    }
                }
            }.tabItem { Text("Requests") }
        })
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        await settle()
        func tabController(_ controller: UIViewController) -> UITabBarController? {
            (controller as? UITabBarController) ?? controller.children.lazy.compactMap { tabController($0) }.first
        }
        let tabs = try XCTUnwrap(tabController(try XCTUnwrap(window.rootViewController)))
        route.path = [1]
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(tabs.isTabBarHidden)
        route.path = []
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertFalse(tabs.isTabBarHidden)
    }

    @Observable final class Route { var path: [Int] = [] }

    private func finish(_ navigation: UINavigationController) async {
        guard let coordinator = navigation.transitionCoordinator else { return }
        await withCheckedContinuation { continuation in
            let registered = coordinator.animate(alongsideTransition: nil) { _ in continuation.resume() }
            if !registered { continuation.resume() }
        }
    }

    private func settle() async {
        // Let UIKit appearance delivery and the deferred SwiftUI-state write finish.
        try? await Task.sleep(for: .milliseconds(50))
    }

    private final class PopDriver: NSObject, UINavigationControllerDelegate, UIViewControllerAnimatedTransitioning {
        var interaction: UIPercentDrivenInteractiveTransition?
        func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation,
                                  from fromVC: UIViewController, to toVC: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? { self }
        func navigationController(_ navigationController: UINavigationController,
                                  interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning) -> (any UIViewControllerInteractiveTransitioning)? { interaction }
        func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval { 0.25 }
        func animateTransition(using context: any UIViewControllerContextTransitioning) {
            guard let from = context.view(forKey: .from), let to = context.view(forKey: .to) else {
                context.completeTransition(false); return
            }
            context.containerView.insertSubview(to, belowSubview: from)
            UIView.animate(withDuration: 0.25, animations: { from.transform = CGAffineTransform(translationX: from.bounds.width, y: 0) }) { _ in
                from.transform = .identity
                context.completeTransition(!context.transitionWasCancelled)
            }
        }
    }
}
