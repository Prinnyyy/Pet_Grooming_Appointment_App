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

private struct BeckonLedgeFace: ViewModifier {
    let face: Color
    let lip: Color
    var edge: Color?
    /// Face while pressed, when it should change colour as well as sink.
    var pressedFace: Color?
    let depth: CGFloat
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let face = face, pressedFace = pressedFace, lip = lip, edge = edge, depth = depth, reduceMotion = reduceMotion
        return BeckonSettledPress(isPressed: isPressed) { pressed in
            let shape = RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.ledgeButton, style: .continuous)
            content
                .background(shape.fill(pressed ? pressedFace ?? face : face))
                .overlay { if let edge { shape.strokeBorder(edge, lineWidth: DesignTokens.Ledge.edgeWidth) } }
                .offset(y: pressed && !reduceMotion ? depth : 0)
                .background { shape.fill(lip).offset(y: depth) }
                .padding(.bottom, depth)
                .contentShape(Rectangle())
                .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.press, value: pressed)
        }
    }
}


struct BeckonPrimaryButtonStyle: ButtonStyle {
    @Environment(\.beckonCustomerDesign) private var usesCustomerDesign

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

    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if usesCustomerDesign { customerBody(configuration: configuration) } else { legacyBody(configuration: configuration) }
    }

    private func customerBody(configuration: Configuration) -> some View {
        let availability = BeckonPrimaryActionAvailability(
            isEnvironmentEnabled: isEnabled,
            isVisuallyEnabled: isVisuallyEnabled
        )

        return configuration.label
            .font(DesignTokens.Typography.Expressive.headline)
            .foregroundStyle(availability.rendersEnabled ? accent.foreground : DesignTokens.Colors.textTertiary)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .modifier(BeckonLedgeFace(
                face: availability.rendersEnabled ? accent.fill : DesignTokens.Colors.iconTileFill,
                lip: availability.rendersEnabled ? (accent == .customer ? DesignTokens.Colors.customerDeep : DesignTokens.Colors.groomerDeep) : DesignTokens.Colors.borderSoft,
                depth: DesignTokens.Ledge.button,
                isPressed: configuration.isPressed && availability.rendersEnabled))
    }

    private func legacyBody(configuration: Configuration) -> some View {
        let availability = BeckonPrimaryActionAvailability(
            isEnvironmentEnabled: isEnabled,
            isVisuallyEnabled: isVisuallyEnabled
        )

        return configuration.label
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
    @Environment(\.beckonCustomerDesign) private var usesCustomerDesign

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

    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if usesCustomerDesign { customerBody(configuration: configuration) } else { legacyBody(configuration: configuration) }
    }

    private func customerBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(isEnabled ? accent.foreground : DesignTokens.Colors.textTertiary)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: DesignTokens.Metrics.minimumTouchTarget)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .modifier(BeckonLedgeFace(
                face: isSelected && isEnabled ? accent.pressedBackground : DesignTokens.Colors.surface,
                lip: isSelected && isEnabled ? accent.foreground : DesignTokens.Colors.border,
                edge: DesignTokens.Colors.border,
                depth: DesignTokens.Ledge.control,
                isPressed: configuration.isPressed && isEnabled))
    }

    private func legacyBody(configuration: Configuration) -> some View {
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
    @Environment(\.beckonCustomerDesign) private var usesCustomerDesign

    @Environment(\.isEnabled) private var isEnabled
    var accent: BeckonRoleAccent = .customer

    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if usesCustomerDesign { customerBody(configuration: configuration) } else { legacyBody(configuration: configuration) }
    }

    private func customerBody(configuration: Configuration) -> some View {
        let isEnabled = isEnabled, accent = accent
        return BeckonSettledPress(isPressed: configuration.isPressed) { pressed in
            configuration.label
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(isEnabled ? accent.deep : DesignTokens.Colors.textTertiary)
                .frame(minWidth: DesignTokens.Metrics.minimumTouchTarget, minHeight: DesignTokens.Metrics.minimumTouchTarget)
                .contentShape(Rectangle())
                .background(isEnabled && pressed ? accent.tint : .clear)
        }
    }

    private func legacyBody(configuration: Configuration) -> some View {
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
    @Environment(\.beckonCustomerDesign) private var usesCustomerDesign

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

    @ViewBuilder var body: some View {
        if usesCustomerDesign { customerBody } else { legacyBody }
    }

    private var customerBody: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                        .strokeBorder(DesignTokens.Colors.customerDeep, lineWidth: DesignTokens.Ledge.edgeWidth + 1)
                }
            }
            .beckonLedge(.card)
    }

    private var legacyBody: some View {
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



/// What a scrolling page is doing right now, so a tap that is really the end of a scroll can be ignored. One instance per
/// scroll view, handed down through the environment by `beckonTracksScroll()`; a scroll view inside another one
/// (a carousel in a page) also answers to the outer one.
@MainActor
final class BeckonScrollActivity {
    var parent: BeckonScrollActivity?
    private(set) var isScrolling = false
    private var lastChange = Date.distantPast

    func update(isScrolling: Bool) {
        self.isScrolling = isScrolling
        lastChange = Date()
    }

    /// Not moving, and not just stopped: a finger that lands to stop a fling or lifts at the end of a drag is not a tap.
    var acceptsTap: Bool {
        !isScrolling && Date().timeIntervalSince(lastChange) > 0.3 && (parent?.acceptsTap ?? true)
    }
}


private struct BeckonScrollActivityKey: EnvironmentKey {
    static let defaultValue: BeckonScrollActivity? = nil
}


extension EnvironmentValues {
    var beckonScrollActivity: BeckonScrollActivity? {
        get { self[BeckonScrollActivityKey.self] }
        set { self[BeckonScrollActivityKey.self] = newValue }
    }
}


private struct BeckonTracksScrollModifier: ViewModifier {
    @Environment(\.beckonScrollActivity) private var outer
    @State private var activity = BeckonScrollActivity()

    func body(content: Content) -> some View {
        content
            .environment(\.beckonScrollActivity, activity)
            .onAppear { activity.parent = outer }
            .onScrollPhaseChange { old, new in
                // Only real scrolling counts. A plain tap passes through `.tracking` and back to `.idle` and must not look like one.
                func moves(_ phase: ScrollPhase) -> Bool { phase == .interacting || phase == .decelerating || phase == .animating }
                if moves(old) || moves(new) { activity.update(isScrolling: moves(new)) }
            }
    }
}


extension View {
    /// Put on a `ScrollView`: the buttons and links inside (guarded styles) stop acting while it moves.
    func beckonTracksScroll() -> some View { modifier(BeckonTracksScrollModifier()) }
}


/// Remembers whether a control has been on the move. Not a gesture: it only looks at where the control is on screen.
final class BeckonTapGuard {
    private var origin: CGPoint?
    private var lastMove = Date.distantPast

    /// Called with the control's position on screen whenever it changes.
    func observe(_ newOrigin: CGPoint) {
        if let origin, abs(origin.x - newOrigin.x) > 0.5 || abs(origin.y - newOrigin.y) > 0.5 { lastMove = Date() }
        origin = newOrigin
    }

    /// A lift is a tap only if the control has held still for a moment (the page is not scrolling, coasting or being dragged)
    /// and the scroll view around it is not moving or just stopped.
    @MainActor
    func allowsTap(activity: BeckonScrollActivity?) -> Bool {
        Date().timeIntervalSince(lastMove) > 0.35 && (activity?.acceptsTap ?? true)
    }
}


private struct BeckonObservesMotionModifier: ViewModifier {
    let tapGuard: BeckonTapGuard

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGPoint.self) { geometry in
            geometry.frame(in: .global).origin
        } action: { origin in
            tapGuard.observe(origin)
        }
    }
}


/// The one place that decides whether a lift is a tap. The platform cancels a tap when the touch turns into a scroll; this
/// repeats that rule explicitly for every ledge and plain button and link, because a drag that starts on a big card and ends
/// over it must never open it. It adds no gesture, so scrolling that starts on a card is untouched, and the wrapped button
/// keeps its own press look (delayed until the touch settles) and its accessibility.
struct BeckonGuardedButtonBody<Style: ButtonStyle>: View {
    let configuration: PrimitiveButtonStyleConfiguration
    let style: Style
    @Environment(\.beckonScrollActivity) private var activity
    @State private var tapGuard = BeckonTapGuard()

    var body: some View {
        Button(role: configuration.role) {
            guard tapGuard.allowsTap(activity: activity) else { return }
            configuration.trigger()
        } label: {
            configuration.label
        }
        .buttonStyle(style)
        .modifier(BeckonObservesMotionModifier(tapGuard: tapGuard))
    }
}


/// `.plain` made scroll-friendly: no chrome, a light dim while pressed, and the dim waits for the touch to settle like every
/// other press, so scrolling over a row does not flash it.
struct BeckonBarePressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let isEnabled = isEnabled
        return BeckonSettledPress(isPressed: configuration.isPressed) { pressed in
            configuration.label.opacity(!isEnabled ? 0.4 : pressed ? 0.6 : 1)
        }
    }
}


/// `.plain` for cards and rows that are links or buttons in a scrolling page, with the same drag-is-not-a-tap rule.
struct BeckonGuardedPlainButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BeckonGuardedButtonBody(configuration: configuration, style: BeckonBarePressStyle())
    }
}
