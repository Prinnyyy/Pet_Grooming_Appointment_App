import SwiftUI


/// Owns the one snackbar of a page. A snackbar is a message with exactly one action that expires with it; a toast is a message with
/// none. The common case is Undo for a removal that is reversible and leaves nothing on the page to reverse it with (a card that
/// disappears from a list): the action has already happened, and the action does the opposite. Showing another snackbar settles
/// the first, and leaving the page does too. Pages keep one of these in `@State` and attach `.snackbar(_)`.
@MainActor
@Observable
final class SnackbarCenter {
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let detail: String?
        let systemImage: String
        let actionTitle: String
        let actionImage: String
        /// How long the action stays available, and how long the countdown bar runs.
        let seconds: TimeInterval
        let action: @MainActor () async -> Void
    }

    private(set) var item: Item?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    func show(title: String, detail: String? = nil, systemImage: String, actionTitle: String = "Undo",
              actionImage: String = "arrow.uturn.backward", action: @escaping @MainActor () async -> Void) {
        let item = Item(title: title, detail: detail, systemImage: systemImage, actionTitle: actionTitle, actionImage: actionImage,
            seconds: FeedbackTimingPolicy.seconds(.snackbar, title, detail), action: action)
        self.item = item
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(item.seconds))
            guard !Task.isCancelled else { return }
            self?.dismiss(item.id)
        }
    }

    func dismiss(_ id: UUID? = nil) {
        guard id == nil || item?.id == id else { return }
        dismissTask?.cancel()
        dismissTask = nil
        item = nil
    }

    /// The person took the action: the snackbar goes first, then the action runs.
    func perform() {
        guard let item else { return }
        dismiss(item.id)
        Task { await item.action() }
    }
}


/// The snackbar: an icon for what was done, what it was done to, and the one action as a mint pill. Same card as a toast, but it
/// takes touches. The countdown bar is the time the action stays available.
struct DesignSnackbar: View {
    let title: String
    let detail: String?
    let systemImage: String
    var actionTitle = "Undo"
    var actionImage = "arrow.uturn.backward"
    let seconds: TimeInterval
    let onAction: () -> Void

    var body: some View {
        BeckonToastCard(title: title, detail: detail, tone: .neutral, duration: seconds) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.Expressive.label.weight(.heavy))
                .foregroundStyle(DesignTokens.Colors.customerDeep)
        } trailing: {
            Button(action: onAction) {
                Label(actionTitle, systemImage: actionImage)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.pill))
            .fixedSize()
            .accessibilityIdentifier("snackbar.action")
        }
    }
}


private struct SnackbarModifier: ViewModifier {
    let center: SnackbarCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                Group {
                    if let item = center.item {
                        DesignSnackbar(title: item.title, detail: item.detail, systemImage: item.systemImage,
                            actionTitle: item.actionTitle, actionImage: item.actionImage, seconds: item.seconds) { center.perform() }
                            .id(item.id)
                            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                            .padding(.bottom, DesignTokens.Spacing.sm)
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap,
                    value: center.item?.id)
            }
            .onChange(of: center.item?.id) { _, id in
                guard id != nil, let item = center.item else { return }
                let spoken = [item.title, item.detail, "\(item.actionTitle) is available"].compactMap { $0 }.joined(separator: ". ")
                UIAccessibility.post(notification: .announcement, argument: spoken)
            }
            .onDisappear { center.dismiss() }
    }
}


extension View {
    /// Shows the page's snackbar over its bottom edge (over content, never moving it).
    func snackbar(_ center: SnackbarCenter) -> some View {
        modifier(SnackbarModifier(center: center))
    }
}
