import SwiftUI

extension View {
    func groomlyFormField(isInvalid: Bool = false) -> some View {
        modifier(GroomlyFormFieldModifier(isInvalid: isInvalid))
    }
}

private struct GroomlyFormFieldModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    let isInvalid: Bool

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
                    .stroke(borderColor, lineWidth: isInvalid ? 1.6 : 1)
            }
            .shadow(
                color: isInvalid ? DesignTokens.Colors.error.opacity(0.28) : .clear,
                radius: isInvalid ? 9 : 0,
                x: 0,
                y: 0
            )
            .opacity(isEnabled ? 1 : 0.64)
    }

    private var backgroundColor: Color {
        isEnabled ? DesignTokens.Colors.surface : DesignTokens.Colors.borderSoft.opacity(0.35)
    }

    private var borderColor: Color {
        if isInvalid {
            return DesignTokens.Colors.error
        }

        return isEnabled ? DesignTokens.Colors.borderSoft : DesignTokens.Colors.borderSoft.opacity(0.7)
    }
}
