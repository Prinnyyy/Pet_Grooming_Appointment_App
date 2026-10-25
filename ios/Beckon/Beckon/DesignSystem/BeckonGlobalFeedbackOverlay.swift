import SwiftUI
import UIKit

/// Displays the shared center's active prompt; its lifetime belongs to the center, not this page.
struct BeckonGlobalFeedbackOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let bottomTabBarClearance = DesignTokens.Spacing.xl * 3 + DesignTokens.Spacing.sm
    static let sheetBottomClearance = DesignTokens.Spacing.xl
    static let actionBarClearance = DesignTokens.Metrics.ledgePrimaryButtonHeight
        + DesignTokens.Layout.actionAreaInset * 2 + DesignTokens.Spacing.sm

    let center: BeckonFeedbackCenter
    var bottomPadding: CGFloat = Self.bottomTabBarClearance
    var isQuiet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // An empty Group never starts its task. Keep this node alive when the last wizard step is quiet.
            Color.clear.frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .task(id: QuietNoticeKey(id: center.notice?.id, isQuiet: isQuiet)) {
                    guard isQuiet, let notice = center.notice else { return }
                    announceIfNeeded()
                    center.clearNotice(id: notice.id)
                }
                .onChange(of: center.animationKey, initial: true) { _, _ in announceIfNeeded() }

            if center.error != nil || (!isQuiet && (center.notice != nil || center.progress != nil)) {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    if let progress = center.progress, !isQuiet {
                        BeckonStatusProgressToast(progress.title, tint: progress.tone.tint)
                    }
                    if let error = center.error {
                        BeckonBottomErrorPrompt(title: error.title, message: error.message,
                            duration: center.remainingPromptSeconds)
                            .id(error.id)
                    }
                    if let notice = center.notice, !isQuiet {
                        BeckonNoticeToast(message: notice.message, duration: center.remainingPromptSeconds)
                            .id(notice.id)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.sm)
                .padding(.bottom, bottomPadding)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap, value: center.animationKey)
        .allowsHitTesting(false)
    }

    private func announceIfNeeded() {
        if let announcement = center.consumeAccessibilityAnnouncement() {
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }

    private struct QuietNoticeKey: Equatable {
        let id: UUID?
        let isQuiet: Bool
    }
}
