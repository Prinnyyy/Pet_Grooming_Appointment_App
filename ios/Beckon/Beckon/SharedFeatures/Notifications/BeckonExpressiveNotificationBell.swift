import SwiftUI

/// Notification bell for expressive (Tier L/M) Customer screens: ledge control, swing on tap and when unread
/// arrives, count badge that pops in. Groomer and Tier C screens keep `BeckonNotificationBellButton`.
struct BeckonExpressiveNotificationBell: View {
    let unreadCount: Int
    let accessibilityIdentifier: String
    let action: () -> Void
    @Environment(\.beckonEntranceReplay) private var replay
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rings = 0
    @State private var badgeShown = false
    @State private var playedReplay: Int?

    private var presentation: BeckonNotificationBellPresentation {
        BeckonNotificationBellPresentation(unreadCount: unreadCount)
    }

    var body: some View {
        let still = reduceMotion
        Button {
            rings += 1
            action()
        } label: {
            Image(systemName: "bell.fill")
                .font(DesignTokens.Typography.Expressive.glyph)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .keyframeAnimator(initialValue: 0.0, trigger: rings) { content, angle in
                    content.rotationEffect(.degrees(still ? 0 : angle), anchor: .top)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-24, duration: 0.10)
                        CubicKeyframe(20, duration: 0.14)
                        CubicKeyframe(-15, duration: 0.14)
                        CubicKeyframe(10, duration: 0.14)
                        CubicKeyframe(-5, duration: 0.12)
                        CubicKeyframe(0, duration: 0.12)
                    }
                }
                .frame(width: DesignTokens.Metrics.ledgeRoundControl, height: DesignTokens.Metrics.ledgeRoundControl)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.round))
        .layoutPriority(1)
        .overlay(alignment: .topTrailing) {
            if presentation.showsUnreadDot {
                BeckonUnreadCountBadge(count: unreadCount, isShown: badgeShown)
                    .offset(x: 5, y: -4)
            }
        }
        .onChange(of: unreadCount) { old, new in
            if new > old { rings += 1 }
        }
        .task(id: replay) {
            guard playedReplay != replay else { return }
            playedReplay = replay
            badgeShown = false
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.bounce) {
                badgeShown = true
            }
            if unreadCount > 0 {
                try? await Task.sleep(for: .milliseconds(250))
                rings += 1
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel("Notifications")
        .accessibilityValue(presentation.accessibilityValue)
    }
}
