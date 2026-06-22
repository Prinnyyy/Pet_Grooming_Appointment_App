import SwiftUI

struct GroomlyPrimaryButtonStyle: ButtonStyle {
    enum Accent {
        case customer
        case groomer

        fileprivate var gradientColors: [Color] {
            switch self {
            case .customer:
                [
                    DesignTokens.Colors.customerPrimary,
                    DesignTokens.Colors.customerPrimaryDark
                ]
            case .groomer:
                [
                    DesignTokens.Colors.groomerAccent,
                    DesignTokens.Colors.groomerAccentDark
                ]
            }
        }

        fileprivate var shadow: DesignTokens.ShadowStyle {
            switch self {
            case .customer:
                DesignTokens.Shadows.primaryAction
            case .groomer:
                DesignTokens.Shadows.groomerAction
            }
        }
    }

    @Environment(\.isEnabled) private var isEnabled

    private let accent: Accent
    private let isFullWidth: Bool

    init(accent: Accent = .customer, isFullWidth: Bool = true) {
        self.accent = accent
        self.isFullWidth = isFullWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.body.weight(.semibold))
            .foregroundStyle(isEnabled ? DesignTokens.Colors.surface : DesignTokens.Colors.textTertiary)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: 44)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button, style: .continuous)
                    .fill(backgroundGradient(isPressed: configuration.isPressed))
            }
            .groomlyShadow(accent.shadow, isVisible: isEnabled)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.64)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isEnabled)
    }

    private func backgroundGradient(isPressed: Bool) -> LinearGradient {
        let colors: [Color]

        if isEnabled {
            colors = isPressed ? Array(accent.gradientColors.reversed()) : accent.gradientColors
        } else {
            colors = [
                DesignTokens.Colors.borderSoft,
                DesignTokens.Colors.borderSoft
            ]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct GroomlySecondaryButtonStyle: ButtonStyle {
    enum Accent {
        case customer
        case groomer
        case neutral

        fileprivate var foreground: Color {
            switch self {
            case .customer:
                DesignTokens.Colors.customerPrimaryDark
            case .groomer:
                DesignTokens.Colors.groomerAccentDark
            case .neutral:
                DesignTokens.Colors.textPrimary
            }
        }

        fileprivate var pressedBackground: Color {
            switch self {
            case .customer:
                DesignTokens.Colors.customerPrimary.opacity(0.14)
            case .groomer:
                DesignTokens.Colors.groomerAccent.opacity(0.14)
            case .neutral:
                DesignTokens.Colors.borderSoft.opacity(0.55)
            }
        }
    }

    @Environment(\.isEnabled) private var isEnabled

    private let accent: Accent
    private let isFullWidth: Bool

    init(accent: Accent = .customer, isFullWidth: Bool = true) {
        self.accent = accent
        self.isFullWidth = isFullWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.body.weight(.semibold))
            .foregroundStyle(isEnabled ? accent.foreground : DesignTokens.Colors.textTertiary)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: 44)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.64)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isEnabled)
    }

    private var borderColor: Color {
        isEnabled ? DesignTokens.Colors.border : DesignTokens.Colors.borderSoft
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isEnabled && isPressed {
            return accent.pressedBackground
        }

        return isEnabled ? DesignTokens.Colors.surface : DesignTokens.Colors.borderSoft.opacity(0.32)
    }
}

struct GroomlyCard<Content: View>: View {
    private let isSelected: Bool
    private let padding: CGFloat
    private let content: Content

    init(
        isSelected: Bool = false,
        padding: CGFloat = DesignTokens.Spacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                    .fill(DesignTokens.Colors.surfaceRaised)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 1.5 : 1)
            }
            .groomlyShadow(DesignTokens.Shadows.softCard)
    }

    private var borderColor: Color {
        isSelected ? DesignTokens.Colors.customerPrimary : DesignTokens.Colors.borderSoft
    }
}

struct GroomlyStatusChip: View {
    enum Tone {
        case neutral
        case customer
        case groomer
        case success
        case warning
        case error

        fileprivate var foreground: Color {
            switch self {
            case .neutral:
                DesignTokens.Colors.textSecondary
            case .customer:
                DesignTokens.Colors.customerPrimaryDark
            case .groomer:
                DesignTokens.Colors.groomerAccentDark
            case .success:
                DesignTokens.Colors.success
            case .warning:
                DesignTokens.Colors.textPrimary
            case .error:
                DesignTokens.Colors.error
            }
        }

        fileprivate var background: Color {
            switch self {
            case .neutral:
                DesignTokens.Colors.borderSoft.opacity(0.55)
            case .customer:
                DesignTokens.Colors.customerPrimary.opacity(0.16)
            case .groomer:
                DesignTokens.Colors.groomerAccent.opacity(0.16)
            case .success:
                DesignTokens.Colors.success.opacity(0.16)
            case .warning:
                DesignTokens.Colors.warning.opacity(0.2)
            case .error:
                DesignTokens.Colors.error.opacity(0.14)
            }
        }

        fileprivate var border: Color {
            switch self {
            case .neutral:
                DesignTokens.Colors.borderSoft
            case .customer:
                DesignTokens.Colors.customerPrimary.opacity(0.34)
            case .groomer:
                DesignTokens.Colors.groomerAccent.opacity(0.34)
            case .success:
                DesignTokens.Colors.success.opacity(0.32)
            case .warning:
                DesignTokens.Colors.warning.opacity(0.34)
            case .error:
                DesignTokens.Colors.error.opacity(0.3)
            }
        }
    }

    private let title: String
    private let systemImage: String?
    private let tone: Tone

    init(
        _ title: String,
        systemImage: String? = nil,
        tone: Tone = .neutral
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }

            Text(title)
                .lineLimit(1)
        }
        .font(DesignTokens.Typography.caption.weight(.semibold))
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(tone.background)
        .overlay {
            DesignTokens.Shapes.chip
                .stroke(tone.border, lineWidth: 1)
        }
        .clipShape(DesignTokens.Shapes.chip)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func groomlyShadow(
        _ style: DesignTokens.ShadowStyle,
        isVisible: Bool = true
    ) -> some View {
        modifier(GroomlyShadowModifier(style: style, isVisible: isVisible))
    }
}

private struct GroomlyShadowModifier: ViewModifier {
    let style: DesignTokens.ShadowStyle
    let isVisible: Bool

    func body(content: Content) -> some View {
        // SwiftUI has no spread parameter, so keep layout stable and approximate spread through radius.
        content.shadow(
            color: isVisible ? style.color : .clear,
            radius: max(0, style.radius + style.spread),
            x: style.x,
            y: style.y
        )
    }
}
