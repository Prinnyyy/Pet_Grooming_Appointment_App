import SwiftUI

/// The value that will apply after a service change is confirmed.
struct GroomerVisitServiceChangeSummary<Content: View>: View {
    let title: String
    var isCardHeader = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title).font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            content()
        }
        .font(DesignTokens.Typography.Expressive.supporting)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, isCardHeader ? DesignTokens.Spacing.lg : DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.groomerTint, in: RoundedRectangle(cornerRadius: isCardHeader ? 0 : DesignTokens.CornerRadius.inset))
        .accessibilityElement(children: .combine)
    }
}
