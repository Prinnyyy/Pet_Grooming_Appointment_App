import SwiftUI

extension View {
    func groomlyFormField() -> some View {
        modifier(GroomlyFormFieldModifier())
    }
}

private struct GroomlyFormFieldModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .font(DesignTokens.Typography.body)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .tint(DesignTokens.Colors.customerPrimaryDark)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .frame(minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                    .fill(backgroundColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.64)
    }

    private var backgroundColor: Color {
        isEnabled ? DesignTokens.Colors.surface : DesignTokens.Colors.borderSoft.opacity(0.35)
    }

    private var borderColor: Color {
        isEnabled ? DesignTokens.Colors.borderSoft : DesignTokens.Colors.borderSoft.opacity(0.7)
    }
}
