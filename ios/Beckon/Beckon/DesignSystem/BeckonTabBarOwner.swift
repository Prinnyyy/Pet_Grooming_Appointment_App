import SwiftUI
import UIKit

/// Keep the existing shell composition API; pushed pages coordinate the bar with UIKit navigation.
struct BeckonTabBarOwner<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { content.background(BeckonTabRootVisibility()) }
}

/// A programmatic tab switch must not inherit another tab's manually hidden bar.
private struct BeckonTabRootVisibility: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}
    final class Controller: UIViewController {
        override func viewDidLoad() { super.viewDidLoad(); view.isUserInteractionEnabled = false }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let tabs = tabBarController, let selected = tabs.selectedViewController,
                  let navigation = findNavigation(selected) else { return }
            if let transition = navigation.transitionCoordinator,
               navigation.viewControllers.contains(where: {
                   $0 === transition.viewController(forKey: .from) || $0 === transition.viewController(forKey: .to)
               }) { return }
            tabs.setTabBarHidden(navigation.topViewController?.hidesBottomBarWhenPushed ?? false, animated: false)
        }
        private func findNavigation(_ controller: UIViewController) -> UINavigationController? {
            (controller as? UINavigationController) ?? controller.children.lazy.compactMap { self.findNavigation($0) }.first
        }
    }
}

extension View {
    /// The native push flag plus its transition coordinator keep the bar underneath the outgoing page,
    /// with a vertical reveal tied to the same interactive progress and cancellation.
    func beckonHidesTabBar() -> some View { background(BeckonTabBarHider()) }
}

private struct BeckonTabBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.markPage() }

    final class Controller: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            markPage()
        }
        override func viewWillAppear(_ animated: Bool) {
            markPage()
            super.viewWillAppear(animated)
            // SwiftUI mounts this bridge after it starts the push. Establish the initial hidden state
            // explicitly; the hosting page's native flag then owns pop progress and cancellation.
            if transitionCoordinator?.isInteractive != true {
                tabBarController?.setTabBarHidden(true, animated: false)
            }
        }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard let navigation = navigationController, let tabs = tabBarController else { return }
            guard let transition = transitionCoordinator else {
                tabs.setTabBarHidden(navigation.topViewController?.hidesBottomBarWhenPushed ?? false, animated: false)
                return
            }
            guard let from = transition.viewController(forKey: .from), owns(from),
                  let destination = transition.viewController(forKey: .to), !destination.hidesBottomBarWhenPushed,
                  let destinationIndex = navigation.viewControllers.firstIndex(where: { $0 === destination }) else { return }
            if let sourceIndex = navigation.viewControllers.firstIndex(where: { $0 === from }), sourceIndex < destinationIndex { return }
            let bar = tabs.tabBar
            // Cover only the bar-sized strip of the outgoing page. This keeps the returning bar below
            // that page even on OS versions whose tab bar is composited above the navigation container.
            let coverHeight = bar.bounds.height + tabs.view.safeAreaInsets.bottom
            let coveredRect = CGRect(x: 0, y: from.view.bounds.maxY - coverHeight,
                width: from.view.bounds.width, height: coverHeight)
            let cover = UIAccessibility.isReduceMotionEnabled ? nil : from.view.resizableSnapshotView(
                from: coveredRect, afterScreenUpdates: false, withCapInsets: .zero)
            tabs.setTabBarHidden(false, animated: false)
            if let parent = bar.superview, let cover {
                cover.frame = from.view.convert(coveredRect, to: parent)
                cover.isUserInteractionEnabled = false
                cover.accessibilityElementsHidden = true
                parent.addSubview(cover)
            }
            let travels = !UIAccessibility.isReduceMotionEnabled
            bar.alpha = 1
            bar.transform = travels ? CGAffineTransform(translationX: 0, y: bar.bounds.height + tabs.view.safeAreaInsets.bottom) : .identity
            let registered = transition.animate(alongsideTransition: { _ in
                bar.alpha = 1
                bar.transform = .identity
                cover?.transform = CGAffineTransform(translationX: from.view.bounds.width, y: 0)
            }) { context in
                cover?.removeFromSuperview()
                bar.transform = .identity
                bar.alpha = 1
                tabs.setTabBarHidden(context.isCancelled, animated: false)
            }
            if !registered {
                cover?.removeFromSuperview()
                bar.transform = .identity
                tabs.setTabBarHidden(false, animated: false)
            }
        }

        private func owns(_ page: UIViewController) -> Bool {
            guard firstHider(in: page) === self else { return false }
            var ancestor: UIViewController? = self
            while let candidate = ancestor {
                if candidate === page { return true }
                ancestor = candidate.parent
            }
            return false
        }

        private func firstHider(in page: UIViewController) -> Controller? {
            (page as? Controller) ?? page.children.lazy.compactMap { self.firstHider(in: $0) }.first
        }

        func markPage() {
            guard let navigation = navigationController else { return }
            var page: UIViewController? = self
            while let controller = page, controller !== navigation {
                controller.hidesBottomBarWhenPushed = true
                page = controller.parent
            }
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
            .beckonNavigationDestination(isPresented: $isPresented) { destination() }
            .beckonResetsNavigation { isPresented = false }
    }
}

// Register secondary destinations through one shared presentation policy.
extension View {
    func beckonNavigationDestination<D: Hashable, Destination: View>(for type: D.Type,
        @ViewBuilder destination: @escaping (D) -> Destination) -> some View {
        navigationDestination(for: type) { destination($0).beckonHidesTabBar() }
    }

    func beckonNavigationDestination<D: Hashable, Destination: View>(item: Binding<D?>,
        @ViewBuilder destination: @escaping (D) -> Destination) -> some View {
        navigationDestination(item: item) { destination($0).beckonHidesTabBar() }
    }

    func beckonNavigationDestination<Destination: View>(isPresented: Binding<Bool>,
        @ViewBuilder destination: @escaping () -> Destination) -> some View {
        navigationDestination(isPresented: isPresented) { destination().beckonHidesTabBar() }
    }
}


/// Restore the native edge-pop for pages with their own header/back button (such as chat).
/// No replacement pan gesture or navigation animator: UIKit still owns progress/cancellation.
extension View {
    func beckonAllowsInteractiveBack() -> some View { background(BeckonInteractiveBackBridge()) }
}

struct BeckonInteractiveBackBridge: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.installIfVisible() }

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        private weak var previousDelegate: (any UIGestureRecognizerDelegate)?
        private weak var gesture: UIGestureRecognizer?
        private var isVisible = false

        override func viewDidLoad() { super.viewDidLoad(); view.isUserInteractionEnabled = false }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            isVisible = true
            installIfVisible()
        }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            isVisible = false
            restore()
        }
        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            isVisible = false
            restore()
        }
        func installIfVisible() {
            guard isVisible, let navigation = navigationController,
                  let gesture = navigation.interactivePopGestureRecognizer, owns(navigation.topViewController) else { return }
            if gesture.delegate !== self {
                previousDelegate = gesture.delegate
                self.gesture = gesture
                gesture.delegate = self
            }
        }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigation = navigationController else { return false }
            return navigation.viewControllers.count > 1 && navigation.transitionCoordinator == nil
                && owns(navigation.topViewController)
        }
        private func owns(_ page: UIViewController?) -> Bool {
            var owner: UIViewController? = self
            while let current = owner {
                if current === page { return true }
                owner = current.parent
            }
            return false
        }
        private func restore() {
            if gesture?.delegate === self { gesture?.delegate = previousDelegate }
            gesture = nil
            previousDelegate = nil
        }
    }
}
