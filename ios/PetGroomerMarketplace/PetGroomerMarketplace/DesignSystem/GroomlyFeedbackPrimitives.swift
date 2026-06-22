import SwiftUI

struct GroomlyErrorBanner<Action: View>: View {
    private let title: String
    private let message: String?
    private let systemImage: String?
    private let showsAction: Bool
    private let action: Action

    init(
        title: String,
        message: String? = nil,
        systemImage: String? = "exclamationmark.triangle.fill",
        @ViewBuilder action: () -> Action
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        showsAction = true
        self.action = action()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.error)
                        .frame(
                            width: DesignTokens.Spacing.xl + DesignTokens.Spacing.sm,
                            height: DesignTokens.Spacing.xl + DesignTokens.Spacing.sm
                        )
                        .background(DesignTokens.Colors.error.opacity(0.12))
                        .clipShape(DesignTokens.Shapes.circular)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    if let message {
                        Text(message)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)

            if showsAction {
                action
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .fill(DesignTokens.Colors.surfaceRaised)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .stroke(DesignTokens.Colors.error.opacity(0.28), lineWidth: 1)
        }
        .groomlyShadow(DesignTokens.Shadows.smallCard)
    }
}

extension GroomlyErrorBanner where Action == EmptyView {
    init(
        title: String,
        message: String? = nil,
        systemImage: String? = "exclamationmark.triangle.fill"
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        showsAction = false
        action = EmptyView()
    }
}

struct GroomlyLoadingView: View {
    enum Accent {
        case customer
        case groomer

        fileprivate var tint: Color {
            switch self {
            case .customer:
                DesignTokens.Colors.customerPrimary
            case .groomer:
                DesignTokens.Colors.groomerAccent
            }
        }
    }

    private let title: String
    private let message: String?
    private let accent: Accent

    init(
        title: String,
        message: String? = nil,
        accent: Accent = .customer
    ) {
        self.title = title
        self.message = message
        self.accent = accent
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .tint(accent.tint)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                if let message {
                    Text(message)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .fill(DesignTokens.Colors.surfaceRaised)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
        }
        .groomlyShadow(DesignTokens.Shadows.smallCard)
        .accessibilityElement(children: .combine)
    }
}

struct GroomlyEmptyState<Action: View>: View {
    enum Accent {
        case customer
        case groomer

        fileprivate var foreground: Color {
            switch self {
            case .customer:
                DesignTokens.Colors.customerPrimaryDark
            case .groomer:
                DesignTokens.Colors.groomerAccentDark
            }
        }

        fileprivate var background: Color {
            switch self {
            case .customer:
                DesignTokens.Colors.customerPrimary.opacity(0.14)
            case .groomer:
                DesignTokens.Colors.groomerAccent.opacity(0.14)
            }
        }
    }

    private let title: String
    private let message: String
    private let systemImage: String?
    private let accent: Accent
    private let showsAction: Bool
    private let action: Action

    init(
        title: String,
        message: String,
        systemImage: String? = "tray",
        accent: Accent = .customer,
        @ViewBuilder action: () -> Action
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.accent = accent
        showsAction = true
        self.action = action()
    }

    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.xl) {
            VStack(spacing: DesignTokens.Spacing.md) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(DesignTokens.Typography.largeTitle)
                        .foregroundStyle(accent.foreground)
                        .frame(
                            width: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl,
                            height: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl
                        )
                        .background(accent.background)
                        .clipShape(DesignTokens.Shapes.circular)
                        .accessibilityHidden(true)
                }

                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text(title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text(message)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)

                if showsAction {
                    action
                        .padding(.top, DesignTokens.Spacing.xs)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

extension GroomlyEmptyState where Action == EmptyView {
    init(
        title: String,
        message: String,
        systemImage: String? = "tray",
        accent: Accent = .customer
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.accent = accent
        showsAction = false
        action = EmptyView()
    }
}

struct GroomlySectionHeader<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let showsTrailing: Bool
    private let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        showsTrailing = true
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsTrailing {
                trailing
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .accessibilityElement(children: .contain)
    }
}

extension GroomlySectionHeader where Trailing == EmptyView {
    init(
        _ title: String,
        subtitle: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        showsTrailing = false
        trailing = EmptyView()
    }
}
