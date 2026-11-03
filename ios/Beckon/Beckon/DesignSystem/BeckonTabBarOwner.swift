// A hidden tab bar stays hidden through interactive navigation, including cancellation.
// Restore it only after the transition completes, using the native bottom-bar animation.
import SwiftUI

import UIKit


/// Whether the pages of one tab, as it stands, want the bar away. The tab's `BeckonTabBarOwner` makes it and reads it;
/// the pages reach it through the environment.
@MainActor
@Observable
final class BeckonTabBarSlot {
    var hidesBar = false
    @ObservationIgnored weak var controller: UITabBarController?
    @ObservationIgnored weak var owner: UIViewController?

    func setHidden(_ hidden: Bool, animated: Bool = false) {
        hidesBar = hidden
        guard let controller, controller.isTabBarHidden != hidden,
              let selected = controller.selectedViewController else { return }
        var ancestor = owner
        while let candidate = ancestor, candidate !== selected { ancestor = candidate.parent }
        guard ancestor === selected else { return }
        controller.setTabBarHidden(hidden, animated: animated && !UIAccessibility.isReduceMotionEnabled)
    }
}


private struct BeckonTabBarSlotKey: EnvironmentKey {
    static let defaultValue: BeckonTabBarSlot? = nil
}


extension EnvironmentValues {
    var beckonTabBarSlot: BeckonTabBarSlot? {
        get { self[BeckonTabBarSlotKey.self] }
        set { self[BeckonTabBarSlotKey.self] = newValue }
    }
}


/// Wraps a tab's navigation stack. The bar is hidden for as long as a page of this tab on the stack asks for it
/// (`.beckonHidesTabBar()`), and returns after the last hidden destination finishes leaving.
struct BeckonTabBarOwner<Content: View>: View {
    @State private var slot = BeckonTabBarSlot()
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.beckonTabBarSlot, slot)
            .background(BeckonTabBarVisibility(slot: slot))
    }
}


private struct BeckonTabBarVisibility: UIViewControllerRepresentable {
    let slot: BeckonTabBarSlot
    func makeUIViewController(context: Context) -> Controller { Controller(slot: slot) }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.apply() }

    final class Controller: UIViewController {
        let slot: BeckonTabBarSlot
        init(slot: BeckonTabBarSlot) { self.slot = slot; super.init(nibName: nil, bundle: nil) }
        required init?(coder: NSCoder) { nil }
        override func viewDidLoad() { super.viewDidLoad(); view.isUserInteractionEnabled = false }
        override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); apply() }
        override func didMove(toParent parent: UIViewController?) { super.didMove(toParent: parent); apply() }
        func apply() {
            guard let bar = tabBarController else { return }
            slot.controller = bar
            slot.owner = self
            slot.setHidden(slot.hidesBar)
        }
    }
}


extension View {
    /// Keep tab-bar ownership in the shared shell, including interactive back cancellation.
    /// Standalone previews without an owner fall back to the system toolbar preference.
    func beckonHidesTabBar() -> some View { modifier(BeckonHidesTabBarModifier()) }
}


private struct BeckonHidesTabBarModifier: ViewModifier {
    @Environment(\.beckonTabBarSlot) private var slot

    func body(content: Content) -> some View {
        if let slot {
            content.background(BeckonTabBarHider(slot: slot))
        } else {
            content.toolbar(.hidden, for: .tabBar)
        }
    }
}


/// Sits behind a page and tells its tab what UIKit tells it: the page is arriving (hide the bar), or is on its way off the stack
/// (look at what is left on it).
private struct BeckonTabBarHider: UIViewControllerRepresentable {
    let slot: BeckonTabBarSlot

    func makeUIViewController(context: Context) -> Controller {
        Controller(slot: slot)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.slot = slot
    }

    final class Controller: UIViewController {
        var slot: BeckonTabBarSlot
        private weak var stack: UINavigationController?
        private var awaitingTransition = false

        init(slot: BeckonTabBarSlot) {
            self.slot = slot
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        /// The page is arriving, or is back after a pop that was started and given up: the bar goes.
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            if parent == nil { settle() } else { hide() }
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            hide()
        }

        /// Wait for completion, not interaction start: a cancelled edge swipe must never expose the bar.
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            remember()
            if let coordinator = transitionCoordinator {
                awaitingTransition = true
                let slot = slot, stack = stack
                let registered = coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                    self?.awaitingTransition = false
                    Self.refresh(slot: slot, stack: stack, animated: true)
                }
                if registered { return }
                awaitingTransition = false
            }
            settle()
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            settle()
        }

        // UIKit calls these from inside the SwiftUI update that pushes or pops (the stack is reconciled there), where the tab's state
        // must not be written, so the tab hears of it a turn later. The turn carries what it needs and not this controller, which a
        // pop may already have let go of.
        private func hide() {
            remember()
            let slot = slot
            Task { slot.setHidden(true) }
        }

        private func settle() {
            guard !awaitingTransition else { return }
            remember()
            Self.refresh(slot: slot, stack: stack, animated: true)
        }

        private static func refresh(slot: BeckonTabBarSlot, stack: UINavigationController?, animated: Bool) {
            Task {
                guard let stack else { return }
                slot.setHidden(stack.viewControllers.contains(where: hostsHider), animated: animated)
            }
        }

        private func remember() {
            if let found = navigationController { stack = found }
        }

        private static func hostsHider(_ controller: UIViewController) -> Bool {
            controller is Controller || controller.children.contains(where: hostsHider)
        }
    }
}

// A stable tab root can contain destination-based pushes that NavigationPath does not represent.
// Notify those bindings on departure; never recreate the root or its Stores to pop a page.
private struct BeckonNavigationResetCountKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var beckonNavigationResetCount: Int {
        get { self[BeckonNavigationResetCountKey.self] }
        set { self[BeckonNavigationResetCountKey.self] = newValue }
    }
}

private struct BeckonNavigationResetObserver: ViewModifier {
    @Environment(\.beckonNavigationResetCount) private var count
    @State private var observed: Int?
    let reset: () -> Void

    func body(content: Content) -> some View {
        content.onAppear { receive(count) }.onChange(of: count) { _, value in receive(value) }
    }

    private func receive(_ value: Int) {
        if let observed, observed != value {
            var cut = Transaction(animation: nil)
            cut.disablesAnimations = true
            withTransaction(cut) { reset() }
        }
        observed = value
    }
}

extension View {
    func beckonResetsNavigation(_ reset: @escaping () -> Void) -> some View {
        modifier(BeckonNavigationResetObserver(reset: reset))
    }
}

/// The modern destination-based counterpart of the customer's typed link. Its binding participates
/// in the shell's reset notification, including when the root reappears after an inactive tab.
struct BeckonNavigationLink<Destination: View, Label: View>: View {
    @ViewBuilder let destination: () -> Destination
    @ViewBuilder let label: () -> Label
    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: { label() }
            .navigationDestination(isPresented: $isPresented) { destination() }
            .beckonResetsNavigation { isPresented = false }
    }
}
