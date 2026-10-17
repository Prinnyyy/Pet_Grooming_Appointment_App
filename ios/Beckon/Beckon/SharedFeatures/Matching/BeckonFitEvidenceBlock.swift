import SwiftUI

struct BeckonFitEvidenceBlock: View {
    let scoreText: String?
    let summary: String
    let reason: String
    let accent: BeckonRoleAccent
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: "sparkles")
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(accent.darkColor)
                .frame(
                    width: DesignTokens.Spacing.xl,
                    height: DesignTokens.Spacing.xl
                )
                .background(accent.color.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    Text("Fit Evidence")
                        .font(DesignTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(accent.darkColor)

                    if let scoreText {
                        Text(scoreText)
                            .font(DesignTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(accent.darkColor)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, 3)
                            .background(accent.color.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }

                Text(isCompact ? summary : reason)
                    .font(isCompact ? DesignTokens.Typography.caption : DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(isCompact ? 2 : nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .fill(accent.color.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .stroke(accent.color.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
