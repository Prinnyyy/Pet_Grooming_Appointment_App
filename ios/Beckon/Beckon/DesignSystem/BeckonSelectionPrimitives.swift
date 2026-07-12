import SwiftUI

struct BeckonSelectionCard<Content: View>: View {
    let isSelected: Bool
    let isInvalid: Bool
    let accent: BeckonRoleAccent
    let action: () -> Void
    let content: Content

    init(
        isSelected: Bool,
        isInvalid: Bool = false,
        accent: BeckonRoleAccent,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.isInvalid = isInvalid
        self.accent = accent
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.Layout.surfaceInset)
                .background(
                    isSelected
                        ? accent.color.opacity(0.22)
                        : DesignTokens.Colors.surface
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.card,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.card,
                        style: .continuous
                    )
                    .stroke(
                        isInvalid
                            ? DesignTokens.Colors.error
                            : (isSelected ? accent.darkColor : DesignTokens.Colors.border),
                        lineWidth: isSelected || isInvalid ? 2 : 1
                    )
                }
                .contentShape(Rectangle())
                .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
        }
        .buttonStyle(.plain)
    }
}
