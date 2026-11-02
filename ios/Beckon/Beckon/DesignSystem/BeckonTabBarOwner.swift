// The tab owns whether its bar is hidden (design). A page that hid the bar said so itself, with `.toolbar(.hidden, for: .tabBar)` on its
// own body, and SwiftUI takes that request back only once the page has left the stack: on the way back the bar arrived a beat after the
// page it returns to, and the page jumped up when it did. (Apple's forums carry the same report for iOS 16 and again for iOS 26; there
// the tab, not the pushed page, owned the bar, and the bar came back with the transition.) Now each tab wraps its navigation stack in
// `BeckonTabBarOwner`, which hides the bar while a page asks for it, and a page asks with `.beckonHidesTabBar()`.
// The page does not say "I am gone" when it is gone but when UIKit starts to take it off the stack, which is also when the bar must
// start to come back; the tab then looks at the stack itself, so a page that only gets covered by another one that hides the bar
// (Fit signals, then Evidence) never lets the bar through in between.
import SwiftUI

import UIKit


/// Whether the pages of one tab, as it stands, want the bar away. The tab's `BeckonTabBarOwner` makes it and reads it;
/// the pages reach it through the environment.
@MainActor
@Observable
final class BeckonTabBarSlot {
    var hidesBar = false
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
/// (`.beckonHidesTabBar()`), and comes back the moment the last of them starts to leave.
struct BeckonTabBarOwner<Content: View>: View {
    @State private var slot = BeckonTabBarSlot()
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.beckonTabBarSlot, slot)
            .toolbar(slot.hidesBar ? .hidden : .automatic, for: .tabBar)
    }
}


extension View {
    /// The page hides the tab bar while it is on the stack. Use this and never `.toolbar(.hidden, for: .tabBar)` on a page: the system
    /// would hand the bar back only after the page is gone (see the top of this file). A page inside a tab without a
    /// `BeckonTabBarOwner` (previewed on its own) falls back to the system's way.
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

        /// A pop has started (the stack no longer holds this page), or the page is covered, or its tab was left: in every case the
        /// stack says whether any page that hides the bar is still on it.
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
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
            Task { slot.hidesBar = true }
        }

        private func settle() {
            remember()
            let slot = slot, stack = stack
            Task { slot.hidesBar = stack?.viewControllers.contains(where: Self.hostsHider) ?? false }
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
