import SwiftUI

struct HomeHeader: View {
    let displayName: String
    let unreadNotificationCount: Int
    var notificationIdentifier = "customer.home.notifications"
    let notificationAction: () -> Void
    /// One size above `Expressive.display` (design): the greeting is the only text of the top, so it carries it; it still follows the
    /// text size setting (up to the largest ordinary size) and shrinks before it wraps.
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = DesignTokens.Metrics.homeTitleSize

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            Text("Hi, \(displayName)!")
                .font(DesignTokens.Typography.Expressive.homeGreeting(size: titleSize))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Metrics.homeTitleMinimumScale)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            BeckonExpressiveNotificationBell(
                unreadCount: unreadNotificationCount,
                accessibilityIdentifier: notificationIdentifier,
                action: notificationAction
            )
        }
    }
}
