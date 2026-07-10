import SwiftUI

struct GroomerWorkspaceSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GroomerGroupedSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(DesignTokens.Colors.surface)
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
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
            }
    }
}

struct GroomerWorkspaceDivider: View {
    var leadingInset: CGFloat = 0

    var body: some View {
        Divider()
            .overlay(DesignTokens.Colors.divider)
            .padding(.leading, leadingInset)
    }
}
