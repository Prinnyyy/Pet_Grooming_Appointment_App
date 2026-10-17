import SwiftUI
import UIKit

nonisolated enum BeckonBadgeLabel {
    static func text(for count: Int) -> String? {
        count > 0 ? (count > 99 ? "99+" : String(count)) : nil
    }
}

// Configure the containing native tab bar, not global UIAppearance, so roles cannot leak.
struct BeckonTabBadgeAppearance: UIViewControllerRepresentable {
    let accent: BeckonRoleAccent

    func makeUIViewController(context: Context) -> Controller {
        Controller(accent: accent)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.accent = accent
        controller.applyAppearance()
    }

    final class Controller: UIViewController {
        var accent: BeckonRoleAccent

        init(accent: BeckonRoleAccent) {
            self.accent = accent
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyAppearance()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyAppearance()
        }

        func applyAppearance() {
            guard let bar = tabBarController?.tabBar else { return }
            let appearance = bar.standardAppearance.copy()
            for layout in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
                for state in [layout.normal, layout.selected, layout.disabled, layout.focused] {
                    state.badgeBackgroundColor = UIColor(accent.tint)
                    state.badgeTextAttributes = [.foregroundColor: UIColor(accent.deep)]
                }
            }
            bar.standardAppearance = appearance
            bar.scrollEdgeAppearance = appearance
        }
    }
}
