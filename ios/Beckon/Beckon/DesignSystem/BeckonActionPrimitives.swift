import SwiftUI

struct BeckonPrimaryActionAvailability: Equatable {
    let isEnvironmentEnabled: Bool
    let isVisuallyEnabled: Bool

    var rendersEnabled: Bool {
        isEnvironmentEnabled && isVisuallyEnabled
    }

    var acceptsTap: Bool {
        isEnvironmentEnabled
    }
}

struct BeckonPrimaryButtonStyle: ButtonStyle {
    enum Accent {
        case customer
        case groomer

        fileprivate var fill: Color {
            self == .customer ? DesignTokens.Colors.customerFill : DesignTokens.Colors.groomerFill
        }

        fileprivate var fillPressed: Color {
            self == .customer ? DesignTokens.Colors.customerFillPressed : DesignTokens.Colors.groomerFillPressed
        }

        fileprivate var foreground: Color {
            self == .customer ? DesignTokens.Colors.customerInk : DesignTokens.Colors.groomerInk
        }
    }

    @Environment(\.isEnabled) private var isEnabled
    private let accent: Accent
    private let isFullWidth: Bool
    private let isVisuallyEnabled: Bool

    init(accent: Accent = .customer, isFullWidth: Bool = true, isVisuallyEnabled: Bool = true) {
        self.accent = accent
        self.isFullWidth = isFullWidth
        self.isVisuallyEnabled = isVisuallyEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        let availability = BeckonPrimaryActionAvailability(
            isEnvironmentEnabled: isEnabled,
            isVisuallyEnabled: isVisuallyEnabled
        )

        configuration.label
            .font(DesignTokens.Typography.action)
            .foregroundStyle(availability.rendersEnabled ? accent.foreground : DesignTokens.Colors.textTertiary)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: DesignTokens.Metrics.actionHeight)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button, style: .continuous)
                    .fill(availability.rendersEnabled
                        ? (configuration.isPressed ? accent.fillPressed : accent.fill)
                        : DesignTokens.Colors.iconTileFill)
            }
            .scaleEffect(configuration.isPressed && availability.rendersEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct BeckonSecondaryButtonStyle: ButtonStyle {
    enum Accent {
        case customer
        case customerHero
        case groomer
        case neutral

        fileprivate var foreground: Color {
            switch self {
            case .customer: DesignTokens.Colors.customerDeep
            case .customerHero: DesignTokens.Colors.customerInk
            case .groomer: DesignTokens.Colors.groomerDeep
            case .neutral: DesignTokens.Colors.textPrimary
            }
        }

        fileprivate var pressedBackground: Color {
            switch self {
            case .customer, .customerHero: DesignTokens.Colors.customerTint
            case .groomer: DesignTokens.Colors.groomerTint
            case .neutral: DesignTokens.Colors.iconTileFill
            }
        }
    }

    @Environment(\.isEnabled) private var isEnabled
    private let accent: Accent
    private let isFullWidth: Bool
    private let font: Font
    private let isSelected: Bool

    init(
        accent: Accent = .customer,
        isFullWidth: Bool = true,
        font: Font = DesignTokens.Typography.action,
        isSelected: Bool = false
    ) {
        self.accent = accent
        self.isFullWidth = isFullWidth
        self.font = font
        self.isSelected = isSelected
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(isEnabled ? accent.foreground : DesignTokens.Colors.textTertiary)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: DesignTokens.Metrics.actionHeight)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button, style: .continuous)
                    .fill(isEnabled && configuration.isPressed ? accent.pressedBackground : DesignTokens.Colors.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button, style: .continuous)
                    .stroke(isSelected && isEnabled ? accent.foreground : DesignTokens.Colors.border, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct BeckonTertiaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var accent: BeckonRoleAccent = .customer

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.action)
            .foregroundStyle(isEnabled ? accent.deep : DesignTokens.Colors.textTertiary)
            .frame(minWidth: DesignTokens.Metrics.minimumTouchTarget, minHeight: DesignTokens.Metrics.minimumTouchTarget)
            .contentShape(Rectangle())
            .background(isEnabled && configuration.isPressed ? accent.tint : .clear)
    }
}

struct BeckonDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var isFullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.action)
            .foregroundStyle(isEnabled ? DesignTokens.Colors.statusErrorText : DesignTokens.Colors.textTertiary)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: DesignTokens.Metrics.actionHeight)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button, style: .continuous)
                    .fill(isEnabled && configuration.isPressed ? DesignTokens.Colors.statusErrorFill : DesignTokens.Colors.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button, style: .continuous)
                    .stroke(DesignTokens.Colors.statusErrorBorder, lineWidth: 1)
            }
    }
}

struct BeckonLoadMoreButton: View {
    let isLoading: Bool
    let accent: BeckonSecondaryButtonStyle.Accent
    let accessibilityIdentifier: String
    let title: String
    let systemImage: String
    let loadingAccessibilityLabel: String
    let action: () async -> Void

    init(
        isLoading: Bool,
        accent: BeckonSecondaryButtonStyle.Accent,
        accessibilityIdentifier: String,
        title: String = "Load More",
        systemImage: String = "chevron.down",
        loadingAccessibilityLabel: String = "Loading more",
        action: @escaping () async -> Void
    ) {
        self.isLoading = isLoading
        self.accent = accent
        self.accessibilityIdentifier = accessibilityIdentifier
        self.title = title
        self.systemImage = systemImage
        self.loadingAccessibilityLabel = loadingAccessibilityLabel
        self.action = action
    }

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            ZStack {
                Label(title, systemImage: systemImage)
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .tint(DesignTokens.Colors.textSecondary)
                        .accessibilityLabel(loadingAccessibilityLabel)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 24)
        }
        .buttonStyle(BeckonSecondaryButtonStyle(accent: accent))
        .disabled(isLoading)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct BeckonCard<Content: View>: View {
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
            .beckonShadow(DesignTokens.Shadows.softCard)
    }

    private var borderColor: Color {
        isSelected ? DesignTokens.Colors.customerDeep : DesignTokens.Colors.borderSoft
    }
}

struct BeckonStatusChip: View {
    nonisolated enum Tone: String, CaseIterable, Equatable, Sendable {
        case neutral
        case success
        case warning
        case error
        case info

        @MainActor fileprivate var foreground: Color {
            switch self {
            case .neutral: DesignTokens.Colors.statusNeutralText
            case .success: DesignTokens.Colors.statusSuccessText
            case .warning: DesignTokens.Colors.statusWarningText
            case .error: DesignTokens.Colors.statusErrorText
            case .info: DesignTokens.Colors.statusInfoText
            }
        }

        @MainActor fileprivate var background: Color {
            switch self {
            case .neutral: DesignTokens.Colors.statusNeutralFill
            case .success: DesignTokens.Colors.statusSuccessFill
            case .warning: DesignTokens.Colors.statusWarningFill
            case .error: DesignTokens.Colors.statusErrorFill
            case .info: DesignTokens.Colors.statusInfoFill
            }
        }

        @MainActor fileprivate var border: Color {
            switch self {
            case .neutral: DesignTokens.Colors.statusNeutralBorder
            case .success: DesignTokens.Colors.statusSuccessBorder
            case .warning: DesignTokens.Colors.statusWarningBorder
            case .error: DesignTokens.Colors.statusErrorBorder
            case .info: DesignTokens.Colors.statusInfoBorder
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
                .fixedSize(horizontal: false, vertical: true)
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
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func beckonShadow(
        _ style: DesignTokens.ShadowStyle,
        isVisible: Bool = true
    ) -> some View {
        modifier(BeckonShadowModifier(style: style, isVisible: isVisible))
    }
}

private struct BeckonShadowModifier: ViewModifier {
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
