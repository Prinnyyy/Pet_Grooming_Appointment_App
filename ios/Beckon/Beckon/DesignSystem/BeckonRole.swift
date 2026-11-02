// The role a screen belongs to (design). The customer's accent is mint, the groomer's is coral, and every accent colour of the kit
// (`Colors.customerFill`, `customerInk`, `customerDeep`, `customerTint`, `customerHeroEnd`, `customerHeroBubble`, `customerHeroDecoration`,
// `customerFillPressed`, and what is built on them: the ledge pill, the skeleton bars, the backdrop, the dialogs) is one colour that
// follows this role: a screen puts `.environment(\.beckonRole, .groomer)` on its root and the same views come out in coral. The
// name `customer…` stays for the customer's own screens, and for the kit that has not been renamed; it means "the accent".
//
// The role travels as a UIKit trait that SwiftUI bridges from the environment (`UITraitBridgedEnvironmentKey`), so a colour can be
// a dynamic `UIColor` that reads it: no view has to be told which colour to use, and the 125 places that name an accent keep working.
//
// What is presented (a cover, a sheet, a dialog) is hosted by a controller of its own, and that controller draws the accent from its
// own UIKit trait, not from the environment (design). The dialogs had the role handed to their cover by name, with `.environment` on
// the content: the environment said "groomer" and the pill was mint all the same (seen in the renderer, and by the user on the
// groomer's Cancel Booking). So the role is also written on the controllers that host the content: `beckonCarriesRole(_:)`
// on the content of every presentation, the role read where it is presented. `beckonSheet` and `beckonCover` do it
// for you and the dialogs' presenter does it for its cover; never a bare `.sheet` or `.fullScreenCover` (the audit counts them).
import SwiftUI
import UIKit


nonisolated enum BeckonRole: Hashable, Sendable {
    case customer
    case groomer
}


nonisolated struct BeckonRoleTrait: UITraitDefinition {
    static let defaultValue = BeckonRole.customer
    static let affectsColorAppearance = true
}


extension UITraitCollection {
    nonisolated var beckonRole: BeckonRole { self[BeckonRoleTrait.self] }
}


extension UIMutableTraits {
    nonisolated var beckonRole: BeckonRole {
        get { self[BeckonRoleTrait.self] }
        set { self[BeckonRoleTrait.self] = newValue }
    }
}


private nonisolated struct BeckonRoleEnvironmentKey: UITraitBridgedEnvironmentKey {
    static let defaultValue = BeckonRole.customer

    static func read(from traitCollection: UITraitCollection) -> BeckonRole {
        traitCollection[BeckonRoleTrait.self]
    }

    static func write(to mutableTraits: inout UIMutableTraits, value: BeckonRole) {
        mutableTraits[BeckonRoleTrait.self] = value
    }
}


extension EnvironmentValues {
    /// Mint (`.customer`, the default) or coral (`.groomer`): see the file's header.
    var beckonRole: BeckonRole {
        get { self[BeckonRoleEnvironmentKey.self] }
        set { self[BeckonRoleEnvironmentKey.self] = newValue }
    }
}


extension BeckonRole {
    /// The same names the kit's `BeckonRoleAccent` uses for the two roles.
    var accent: BeckonRoleAccent {
        switch self {
        case .customer: .customer
        case .groomer: .groomer
        }
    }
}


// MARK: Presented controllers

/// Sits behind the content of a presentation and writes the role on the controllers that host it: the one it is in and those above it
/// up to the presented one (a sheet that holds a navigation stack has several). It writes again when the layout runs, because the
/// presentation may set its own trait after this has been added.
private struct BeckonRoleCarrier: UIViewControllerRepresentable {
    let role: BeckonRole

    func makeUIViewController(context: Context) -> Carrier {
        Carrier(role: role)
    }

    func updateUIViewController(_ carrier: Carrier, context: Context) {
        carrier.role = role
        carrier.apply()
    }

    final class Carrier: UIViewController {
        var role: BeckonRole

        init(role: BeckonRole) {
            self.role = role
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func willMove(toParent parent: UIViewController?) {
            super.willMove(toParent: parent)
            apply(from: parent)
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            apply()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            apply()
        }

        func apply() {
            apply(from: parent)
        }

        private func apply(from start: UIViewController?) {
            var node = start
            while let controller = node {
                controller.traitOverrides.beckonRole = role
                if controller.presentingViewController != nil { break }
                node = controller.parent
            }
        }
    }
}


extension View {
    /// For the content of a cover, a sheet or a popover: the role (read where it is presented, outside it) in the environment and on the
    /// controllers that host the content, which is what draws the accent (see the file's header).
    func beckonCarriesRole(_ role: BeckonRole) -> some View {
        environment(\.beckonRole, role)
            .background(BeckonRoleCarrier(role: role))
    }

    /// `.sheet(isPresented:)` for a sheet in the page's role. Use it, never the bare `.sheet`.
    func beckonSheet<Sheet: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Sheet) -> some View {
        modifier(BeckonSheetModifier(isPresented: isPresented, onDismiss: onDismiss, sheet: content))
    }

    /// `.sheet(item:)` for a sheet in the page's role.
    func beckonSheet<Item: Identifiable, Sheet: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil,
                                                               @ViewBuilder content: @escaping (Item) -> Sheet) -> some View {
        modifier(BeckonSheetItemModifier(item: item, onDismiss: onDismiss, sheet: content))
    }

    /// `.fullScreenCover(item:)` for a cover in the page's role. (The dialogs' own cover is in `DesignDialog.swift`.)
    func beckonCover<Item: Identifiable, Cover: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil,
                                                               @ViewBuilder content: @escaping (Item) -> Cover) -> some View {
        modifier(BeckonCoverItemModifier(item: item, onDismiss: onDismiss, cover: content))
    }
}


private struct BeckonSheetModifier<Sheet: View>: ViewModifier {
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?
    let sheet: () -> Sheet
    @Environment(\.beckonRole) private var role

    func body(content: Content) -> some View {
        let role = role
        content.sheet(isPresented: $isPresented, onDismiss: onDismiss) { sheet().beckonCarriesRole(role) }
    }
}


private struct BeckonSheetItemModifier<Item: Identifiable, Sheet: View>: ViewModifier {
    @Binding var item: Item?
    let onDismiss: (() -> Void)?
    let sheet: (Item) -> Sheet
    @Environment(\.beckonRole) private var role

    func body(content: Content) -> some View {
        let role = role
        content.sheet(item: $item, onDismiss: onDismiss) { sheet($0).beckonCarriesRole(role) }
    }
}


private struct BeckonCoverItemModifier<Item: Identifiable, Cover: View>: ViewModifier {
    @Binding var item: Item?
    let onDismiss: (() -> Void)?
    let cover: (Item) -> Cover
    @Environment(\.beckonRole) private var role

    func body(content: Content) -> some View {
        let role = role
        content.fullScreenCover(item: $item, onDismiss: onDismiss) { cover($0).beckonCarriesRole(role) }
    }
}
