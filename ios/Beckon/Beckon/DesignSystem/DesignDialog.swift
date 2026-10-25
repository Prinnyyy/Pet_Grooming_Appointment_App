import SwiftUI


// Two dialogs, one look: a white ledge card on a dimmed page, an icon disc, a centered title and message, and stacked buttons.
//  - Alert dialog (`DesignAlertDialog`): interrupts to ask for ONE decision (confirm a send, confirm something that cannot
//    be taken back). No close button, the scrim does not dismiss it, the person answers with a button.
//  - Modal (`DesignModal`): a short explanation or a small choice that can wait. A close button, the scrim dismisses it,
//    and it can hold content between the message and the buttons.
// Both are presented as a clear full-screen cover, so they cover the navigation bar, the tab bar and any sheet, and VoiceOver
// treats everything behind them as unreachable. Use `.designAlertDialog` / `.designModal`, never SwiftUI's
// `.alert` or `.confirmationDialog` (system look, no icon, no ledge).


/// One button of a dialog. Listed top to bottom in the order given: the pill first, quiet actions under it.
struct DesignDialogAction: Identifiable {
    enum Role {
        /// The mint pill: the answer the dialog hopes for, or the safe one when the other choice cannot be taken back.
        case primary
        /// A calm text action: Cancel, Not now, OK next to a pill.
        case quiet
        /// A quiet red action: the choice that cannot be taken back. Never a big red fill.
        case destructive
    }

    let id = UUID()
    let title: String
    let systemImage: String
    let role: Role
    let identifier: String?
    /// Read while the dialog draws, so a button can wait for what the dialog's own content collects (a note, a time): read an
    /// `@Observable` the content writes to and the button enables itself.
    var isEnabled: @MainActor () -> Bool = { true }
    let perform: @MainActor () -> Void

    static func primary(_ title: String, systemImage: String = "checkmark", identifier: String? = nil,
                        perform: @escaping @MainActor () -> Void = {}) -> Self {
        Self(title: title, systemImage: systemImage, role: .primary, identifier: identifier, perform: perform)
    }

    /// A pill that waits: it is disabled while `isEnabled` says no (see `isEnabled`).
    static func primary(_ title: String, systemImage: String = "checkmark", identifier: String? = nil,
                        isEnabled: @escaping @MainActor () -> Bool,
                        perform: @escaping @MainActor () -> Void) -> Self {
        Self(title: title, systemImage: systemImage, role: .primary, identifier: identifier, isEnabled: isEnabled, perform: perform)
    }

    static func quiet(_ title: String, systemImage: String = "xmark", identifier: String? = nil,
                      perform: @escaping @MainActor () -> Void = {}) -> Self {
        Self(title: title, systemImage: systemImage, role: .quiet, identifier: identifier, perform: perform)
    }

    static func destructive(_ title: String, systemImage: String = "trash", identifier: String? = nil,
                            perform: @escaping @MainActor () -> Void) -> Self {
        Self(title: title, systemImage: systemImage, role: .destructive, identifier: identifier, perform: perform)
    }
}


/// What a dialog says and offers; the alert and the modal both reduce to this.
struct DesignDialogSpec {
    var systemImage: String?
    var tone = DesignIconDisc.Tone.customer
    var title: String
    var message: String?
    var content: AnyView?
    var actions: [DesignDialogAction]
}


/// An alert dialog: one decision, asked in a sentence. Build it with `.destructive` or `.confirmation`; those two cover the cases,
/// and they fix which button is the pill so the safe choice always looks like the safe choice.
struct DesignAlertDialog {
    var systemImage: String
    var tone = DesignIconDisc.Tone.customer
    var title: String
    var message: String?
    var actions: [DesignDialogAction]

    /// Something that cannot be taken back (cancel a request, withdraw an invitation, delete an account). Caution disc; keeping
    /// things as they are is the pill, the destructive answer is a quiet red action under it.
    static func destructive(title: String, message: String? = nil, systemImage: String = "exclamationmark.triangle.fill",
                            keepTitle: String, keepSystemImage: String = "arrow.uturn.backward",
                            confirmTitle: String, confirmSystemImage: String = "trash",
                            confirmIdentifier: String? = nil, confirm: @escaping @MainActor () -> Void) -> Self {
        Self(systemImage: systemImage, tone: .caution, title: title, message: message, actions: [
            .primary(keepTitle, systemImage: keepSystemImage, identifier: "dialog.keep"),
            .destructive(confirmTitle, systemImage: confirmSystemImage, identifier: confirmIdentifier ?? "dialog.confirm", perform: confirm)
        ])
    }

    /// A step that commits something the person chose (send a request): the confirm is the pill, Cancel is quiet.
    static func confirmation(title: String, message: String? = nil, systemImage: String, confirmTitle: String,
                             confirmSystemImage: String = "checkmark", confirmIdentifier: String? = nil,
                             cancelTitle: String = "Cancel", confirm: @escaping @MainActor () -> Void) -> Self {
        Self(systemImage: systemImage, title: title, message: message, actions: [
            .primary(confirmTitle, systemImage: confirmSystemImage, identifier: confirmIdentifier ?? "dialog.confirm", perform: confirm),
            .quiet(cancelTitle, identifier: "dialog.cancel")
        ])
    }

    fileprivate var spec: DesignDialogSpec {
        DesignDialogSpec(systemImage: systemImage, tone: tone, title: title, message: message, content: nil, actions: actions)
    }
}


/// A modal: an explanation or a small choice that can wait. Close button, scrim dismisses, optional content between the message and
/// the buttons. With no actions it is just read and closed. A single action is the pill.
struct DesignModal {
    var systemImage: String?
    var tone = DesignIconDisc.Tone.customer
    var title: String
    var message: String?
    var content: AnyView?
    var actions: [DesignDialogAction]

    init(systemImage: String? = nil, tone: DesignIconDisc.Tone = .customer, title: String, message: String? = nil,
         actions: [DesignDialogAction] = []) {
        self.systemImage = systemImage
        self.tone = tone
        self.title = title
        self.message = message
        self.content = nil
        self.actions = actions
    }

    init<Content: View>(systemImage: String? = nil, tone: DesignIconDisc.Tone = .customer, title: String,
                        message: String? = nil, actions: [DesignDialogAction] = [],
                        @ViewBuilder content: () -> Content) {
        self.init(systemImage: systemImage, tone: tone, title: title, message: message, actions: actions)
        self.content = AnyView(content())
    }

    fileprivate var spec: DesignDialogSpec {
        DesignDialogSpec(systemImage: systemImage, tone: tone, title: title, message: message, content: content, actions: actions)
    }
}


extension View {
    /// Asks one decision over the whole screen. `dialog` is read once, when `isPresented` turns true, so what the dialog says does
    /// not change while it leaves. Choosing a button closes the dialog first, then runs the button's action.
    func designAlertDialog(isPresented: Binding<Bool>, _ dialog: @escaping () -> DesignAlertDialog) -> some View {
        modifier(DesignDialogPresenter(isPresented: isPresented, style: .alert) { dialog().spec })
    }

    /// The same, for a dialog about a thing (the invitation to withdraw): shown while `item` is set, built from it once.
    func designAlertDialog<Item>(item: Binding<Item?>, _ dialog: @escaping (Item) -> DesignAlertDialog) -> some View {
        modifier(DesignDialogPresenter(
            isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } }),
            style: .alert) { item.wrappedValue.map { dialog($0).spec } })
    }

    /// Shows an explanation or a small choice over the whole screen; the close button and a tap outside dismiss it.
    func designModal(isPresented: Binding<Bool>, _ modal: @escaping () -> DesignModal) -> some View {
        modifier(DesignDialogPresenter(isPresented: isPresented, style: .modal) { modal().spec })
    }

    /// The same, for a modal about a thing: shown while `item` is set, built from it once.
    func designModal<Item>(item: Binding<Item?>, _ modal: @escaping (Item) -> DesignModal) -> some View {
        modifier(DesignDialogPresenter(
            isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } }),
            style: .modal) { item.wrappedValue.map { modal($0).spec } })
    }
}


/// One dialog at a time: a dialog that follows another (delete account asks twice) waits for the first to be gone, because UIKit
/// refuses a cover while another is still leaving.
@MainActor
private enum DesignDialogSequence {
    private static var freeAt = ContinuousClock.now

    static func closing() {
        freeAt = ContinuousClock.now + .milliseconds(320)
    }

    static func waitForTurn() async {
        let wait = freeAt - ContinuousClock.now
        if wait > .zero { try? await Task.sleep(for: wait) }
    }
}


private struct DesignDialogPresenter: ViewModifier {
    enum Style { case alert, modal }

    @Binding var isPresented: Bool
    let style: Style
    let make: () -> DesignDialogSpec?
    @State private var isCovering = false
    @State private var isShowing = false
    @State private var spec: DesignDialogSpec?

    /// The body reads `spec` and `isShowing` itself and hands the cover plain values. A cover's content closure that reads this
    /// modifier's state only inside the closure leaves the dialog blank when the caller's own `@State` drives it: the body never
    /// depends on that state, so it is not run again once the spec is set and the cover is presented empty.
    func body(content: Content) -> some View {
        let spec = spec
        let isShowing = isShowing
        content
            .fullScreenCover(isPresented: $isCovering) {
                Group {
                    if let spec {
                        DesignDialogStage(spec: spec, style: style, isPresented: isShowing) {
                            DesignDialogSequence.closing()
                            self.isShowing = false
                            isPresented = false
                        }
                    }
                }
                .presentationBackground(.clear)
            }
            .onChange(of: isPresented, initial: true) { _, wantsDialog in
                if wantsDialog { cover() } else { uncover() }
            }
    }

    /// The cover itself never animates (its slide-up would carry the scrim with it); the stage animates scrim and card.
    private func cover() {
        guard let made = make() else { return }
        spec = made
        isShowing = true
        Task { @MainActor in
            await DesignDialogSequence.waitForTurn()
            guard isPresented else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { isCovering = true }
        }
    }

    /// The stage fades out first (0.16 s); the cover goes after it.
    private func uncover() {
        isShowing = false
        guard isCovering else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard !isPresented else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { isCovering = false }
        }
    }
}


private struct DesignDialogStage: View {
    let spec: DesignDialogSpec
    let style: DesignDialogPresenter.Style
    let isPresented: Bool
    let close: () -> Void
    @State private var hasArrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isVisible: Bool { hasArrived && isPresented }

    var body: some View {
        ZStack {
            scrim
            DesignDialogCard(spec: spec, showsClose: style == .modal, close: close) { action in
                close()
                action.perform()
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.xl)
            .frame(maxWidth: DesignTokens.Metrics.dialogMaxWidth + DesignTokens.Spacing.screenHorizontal * 2)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.9)
            .offset(y: isVisible || reduceMotion ? 0 : 18)
            .opacity(isVisible ? 1 : 0)
        }
        .animation(reduceMotion ? DesignTokens.Motion.reduced
            : isVisible ? DesignTokens.Motion.dialogEnter : DesignTokens.Motion.dialogExit, value: isVisible)
        .allowsHitTesting(isVisible)
        .onAppear { hasArrived = true }
    }

    /// A modal's scrim is a control (tap outside closes) and says so to VoiceOver; an alert's is only dimming.
    @ViewBuilder
    private var scrim: some View {
        let dim = DesignTokens.Colors.scrim
            .ignoresSafeArea()
            .opacity(isVisible ? 1 : 0)
        if style == .modal {
            dim
                .contentShape(Rectangle())
                .onTapGesture(perform: close)
                .accessibilityElement()
                .accessibilityLabel("Close")
                .accessibilityAddTraits(.isButton)
        } else {
            dim.accessibilityHidden(true)
        }
    }
}


/// The shared face of both dialogs. Too tall for the screen (accessibility sizes), the text scrolls and the buttons stay in view.
struct DesignDialogCard: View {
    let spec: DesignDialogSpec
    let showsClose: Bool
    let close: () -> Void
    let choose: (DesignDialogAction) -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            stack(scrolls: false)
            stack(scrolls: true)
        }
        .frame(maxWidth: .infinity)
        .beckonLedge(.card)
        .overlay(alignment: .topTrailing) {
            if showsClose { closeButton }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            if showsClose { close() }
        }
    }

    private func stack(scrolls: Bool) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if scrolls {
                ScrollView { header }
                    .scrollBounceBehavior(.basedOnSize)
            } else {
                header
            }

            if !spec.actions.isEmpty {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(spec.actions) { action in
                        actionButton(action)
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if let systemImage = spec.systemImage {
                DesignIconDisc(systemImage: systemImage, size: .large,
                    font: DesignTokens.Typography.Expressive.title, tone: spec.tone)
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            }

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(spec.title)
                    .font(DesignTokens.Typography.Expressive.title)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if let message = spec.message {
                    Text(message)
                        .designSupportingText()
                        .multilineTextAlignment(.center)
                }
            }

            if let content = spec.content { content }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func actionButton(_ action: DesignDialogAction) -> some View {
        switch action.role {
        case .primary:
            Button { choose(action) } label: {
                DesignActionLabel(title: action.title, systemImage: action.systemImage)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.pill))
            .disabled(!action.isEnabled())
            .accessibilityIdentifier(action.identifier ?? "dialog.primary")
        case .quiet, .destructive:
            Button { choose(action) } label: {
                DesignQuietAction(title: action.title, systemImage: action.systemImage,
                    isDestructive: action.role == .destructive)
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityIdentifier(action.identifier ?? "dialog.quiet")
        }
    }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(DesignTokens.Typography.Expressive.label)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: DesignTokens.Metrics.minimumTouchTarget)
                .contentShape(Circle())
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
        .padding(DesignTokens.Spacing.xs)
        .accessibilityLabel("Close")
        .accessibilityIdentifier("dialog.close")
    }
}
