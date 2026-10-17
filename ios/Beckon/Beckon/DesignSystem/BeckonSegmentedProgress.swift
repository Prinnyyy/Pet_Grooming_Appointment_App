import SwiftUI

struct BeckonSegmentedProgress: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let labels: [String]
    let currentStep: Int
    let accent: BeckonRoleAccent
    let accessibilitySummary: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(labels.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < currentStep ? accent.deep : DesignTokens.Colors.borderSoft)
                        .frame(height: DesignTokens.Spacing.xs)
                }
            }
            labelLayout {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(labelColor(step: index + 1))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var labelLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.sm))
    }

    private func labelColor(step: Int) -> Color {
        if step == currentStep { return DesignTokens.Colors.textPrimary }
        return step < currentStep ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.textTertiary
    }
}
