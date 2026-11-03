import SwiftUI

// The machine owns press order; this file owns timing and drawing. No press gesture is added to scrolling content.

enum BeckonPressTiming {
    /// How long a tap that lifted too soon to settle holds the full press, so that it is seen.
    static let pulseHoldMilliseconds = 70
    /// What the first instant of a touch shows, as a share of the full press.
    static let touchedShare: CGFloat = 0.4
    /// The touch landing: quick, not a spring, so a finger that lands to scroll leaves nothing to see.
    static let acknowledge = Animation.easeOut(duration: 0.07)
    /// A touch taken away by a scroll or dragged off: it fades back, without a bounce.
    static let cancel = Animation.easeOut(duration: 0.12)
    /// The first half of a tap's pulse: a faster spring than `Motion.press`, because it has less than a tenth of a second.
    static let pulseDown = Animation.spring(response: 0.18, dampingFraction: 0.7)
}


/// How far a plain control moves at the full press. Sizes decide: a 24 pt icon needs a stronger move than a card to be seen.
enum BeckonPressMeasure {
    /// A card or tile narrows by about this many points; the scale it loses stays between `surfaceLoss`.
    static let surfaceTravel: CGFloat = 10
    static let surfaceLoss: ClosedRange<CGFloat> = 0.02...0.06
    /// A control whose longest side is up to this is an icon: it shrinks to `compactScale` and a halo grows around it.
    static let compactSide: CGFloat = 64
    static let compactScale: CGFloat = 0.88
    static let haloGrowth: CGFloat = 8
    /// A control no taller than this and wider than an icon is a text link: it dims and shrinks a little.
    static let inlineHeight: CGFloat = 48
    static let inlineScale: CGFloat = 0.97
    static let inlineDim: CGFloat = 0.45
}


/// What a plain control is. `automatic` reads the control's size, so a call site names a kind only when the size misleads (a row).
enum BeckonPressKind: Equatable {
    case automatic, surface, compact, inline, row

    func resolved(for size: CGSize) -> Self {
        guard self == .automatic else { return self }
        let longest = max(size.width, size.height)
        if longest > 0, longest <= BeckonPressMeasure.compactSide { return .compact }
        if size.height > 0, size.height <= BeckonPressMeasure.inlineHeight { return .inline }
        return .surface
    }
}


// MARK: Environment

private struct BeckonTapCountKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    /// How many taps the button around has fired. The guarded and counting bodies count; the engine plays a pulse when it changes.
    var beckonTapCount: Int {
        get { self[BeckonTapCountKey.self] }
        set { self[BeckonTapCountKey.self] = newValue }
    }
}

/// One engine per control. Timers are cancelled on reset; disabled or disappearing views cannot emit a late buzz.
struct BeckonPressEngine<Content: View>: View {
    let isPressed: Bool
    let haptic: SensoryFeedback?
    let content: (CGFloat) -> Content
    @Environment(\.beckonTapCount) private var taps
    @Environment(\.beckonScrollActivity) private var activity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @State private var machine = BeckonPressMachine()
    @State private var amount: CGFloat = 0
    @State private var hapticCount = 0
    @State private var settleTask: Task<Void, Never>?
    @State private var pulseTask: Task<Void, Never>?

    init(isPressed: Bool, haptic: SensoryFeedback? = nil, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.isPressed = isPressed
        self.haptic = haptic
        self.content = content
    }

    var body: some View {
        Group {
            if let haptic { content(amount).sensoryFeedback(haptic, trigger: hapticCount) }
            else { content(amount) }
        }
            .onChange(of: isPressed) { _, down in
                guard isEnabled else { reset(); return }
                if down {
                    guard activity?.acceptsTap ?? true else { return }
                    send(.down)
                } else { send(.up) }
            }
            .onChange(of: taps) { old, new in
                guard new > old else { return }
                for _ in old..<new { send(.tap) }
            }
            .onChange(of: isEnabled) { _, enabled in if !enabled { reset() } }
            .onDisappear { reset() }
    }

    private func send(_ event: BeckonPressMachine.Event) {
        for effect in machine.send(event) {
            switch effect {
            case let .move(level, pace):
                let target: CGFloat = switch level {
                case .rest: 0
                case .touched: BeckonPressTiming.touchedShare
                case .pressed: 1
                }
                withAnimation(animation(for: pace)) { amount = target }
            case .startSettleTimer:
                settleTask?.cancel()
                settleTask = Task {
                    try? await Task.sleep(for: .milliseconds(DesignTokens.Motion.pressSettleMilliseconds))
                    guard !Task.isCancelled, isEnabled else { return }
                    // A scroll may have started after the initial touch but before the settle deadline.
                    guard activity?.acceptsTap ?? true else { send(.up); return }
                    send(.settled)
                }
            case .cancelSettleTimer:
                settleTask?.cancel(); settleTask = nil
            case .startPulseTimer:
                pulseTask?.cancel()
                pulseTask = Task {
                    try? await Task.sleep(for: .milliseconds(BeckonPressTiming.pulseHoldMilliseconds))
                    guard !Task.isCancelled else { return }
                    send(.pulseEnded)
                }
            case .cancelPulseTimer:
                pulseTask?.cancel(); pulseTask = nil
            case .haptic: if haptic != nil { hapticCount += 1 }
            }
        }
    }

    private func reset() {
        settleTask?.cancel(); settleTask = nil
        pulseTask?.cancel(); pulseTask = nil
        machine = BeckonPressMachine()
        var instant = Transaction(animation: nil)
        instant.disablesAnimations = true
        withTransaction(instant) { amount = 0 }
    }

    private func animation(for pace: BeckonPressMachine.Pace) -> Animation {
        if reduceMotion { return DesignTokens.Motion.reduced }
        switch pace {
        case .acknowledge: return BeckonPressTiming.acknowledge
        case .press, .release: return DesignTokens.Motion.press
        case .pulseDown: return BeckonPressTiming.pulseDown
        case .cancel: return BeckonPressTiming.cancel
        }
    }
}

/// Base actions count activations without the scrolling/layout guard. Keyboard movement cannot swallow Continue or Save.
struct BeckonPressCountingBody<Style: ButtonStyle>: View {
    let configuration: PrimitiveButtonStyleConfiguration
    let style: Style
    @State private var taps = 0

    var body: some View {
        Button(role: configuration.role) {
            taps += 1
            configuration.trigger()
        } label: { configuration.label }
        .buttonStyle(style)
        .environment(\.beckonTapCount, taps)
    }
}

/// Keeps each existing base action's layout and accent API while the counting body owns activation.
struct BeckonPressActionLook<Content: View>: ButtonStyle {
    let content: (ButtonStyleConfiguration) -> Content
    func makeBody(configuration: Configuration) -> some View { content(configuration) }
}

extension BeckonLedgeSurface {
    /// The face while pressed, in the role's own colours: a white card goes pale, a mint pill goes deeper, a pink card goes deeper pink.
    var pressedFace: Color {
        switch self {
        case .card, .round, .primary, .dashed: DesignTokens.Colors.customerTint
        case .pill: DesignTokens.Colors.customerFillPressed
        case .highlight: DesignTokens.Colors.customerHeroBubble
        }
    }
}

struct BeckonPressFace: ViewModifier {
    let face: Color
    let pressedFace: Color
    let lip: Color
    var edge: Color?
    let depth: CGFloat
    let radius: CGFloat
    let amount: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                ZStack {
                    shape.fill(face)
                    shape.fill(pressedFace).opacity(min(1, max(0, amount)))
                }
            }
            .overlay { if let edge { shape.strokeBorder(edge, lineWidth: DesignTokens.Ledge.edgeWidth) } }
            .offset(y: reduceMotion ? 0 : depth * amount)
            .background { shape.fill(lip).offset(y: depth) }
            .padding(.bottom, depth)
            .contentShape(Rectangle())
    }
}


// MARK: Plain

/// `.plain` for cards, tiles, icons, links and rows: no chrome, and a press that fits what the control is. What it is comes from its
/// kind or, for `automatic`, from its size (see `BeckonPressMeasure`). It dims nothing it does not have to: a card narrows
/// and takes the role's tint, so it stays a card instead of turning into a ghost.
struct BeckonPressPlainStyle: ButtonStyle {
    var kind = BeckonPressKind.automatic
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        BeckonPlainPressBody(label: configuration.label, isPressed: configuration.isPressed && isEnabled,
            isEnabled: isEnabled, kind: kind)
    }
}


private struct BeckonPlainPressBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let isEnabled: Bool
    let kind: BeckonPressKind
    @State private var size = CGSize.zero

    var body: some View {
        BeckonPressEngine(isPressed: isPressed) { amount in
            label
                .onGeometryChange(for: CGSize.self) { geometry in geometry.size } action: { size = $0 }
                .modifier(BeckonPlainPressLook(kind: resolved, amount: amount, size: size))
                .opacity(isEnabled ? 1 : 0.4)
        }
    }

    private var resolved: BeckonPressKind {
        kind.resolved(for: size)
    }
}


struct BeckonPlainPressLook: ViewModifier {
    let kind: BeckonPressKind
    let amount: CGFloat
    let size: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let share = min(1, max(0, amount))
        let motion: CGFloat = reduceMotion ? 0 : 1
        let surface = kind == .surface || kind == .automatic
        let longest = max(size.width, size.height, 1)
        let surfaceLoss = min(max(BeckonPressMeasure.surfaceTravel / longest, BeckonPressMeasure.surfaceLoss.lowerBound),
            BeckonPressMeasure.surfaceLoss.upperBound)
        let loss: CGFloat = switch kind {
        case .compact: 1 - BeckonPressMeasure.compactScale
        case .inline: 1 - BeckonPressMeasure.inlineScale
        case .row: 0
        case .surface, .automatic: surfaceLoss
        }
        // Keep the label's identity when automatic classification learns its size. Only decoration changes.
        // Tint belongs inside the scale, so it cannot leave an unscaled frame around a pressed card.
        content
            .modifier(BeckonPressSurfaceTint(share: surface ? share : 0))
            .scaleEffect(1 - loss * amount * motion)
            .opacity(kind == .inline ? 1 - BeckonPressMeasure.inlineDim * share : 1)
            .background {
                if kind == .compact {
                    Circle()
                        .fill(DesignTokens.Colors.customerTint)
                        .padding(-BeckonPressMeasure.haloGrowth)
                        .opacity(share)
                } else if kind == .row {
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.inset, style: .continuous)
                        .fill(DesignTokens.Colors.customerTint)
                        .padding(DesignTokens.Spacing.xs)
                        .opacity(share)
                }
            }
    }
}

// Photos and brand artwork keep their colors while the surrounding plain card takes the role's tint.
private struct BeckonPressProtectedBoundsKey: PreferenceKey {
    static var defaultValue: [Anchor<CGRect>] { [] }
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) { value += nextValue() }
}

extension View {
    func beckonPreservesPressColors() -> some View {
        anchorPreference(key: BeckonPressProtectedBoundsKey.self, value: .bounds) { [$0] }
    }
}

struct BeckonPressSurfaceTint: ViewModifier {
    let share: CGFloat
    func body(content: Content) -> some View {
        content.overlayPreferenceValue(BeckonPressProtectedBoundsKey.self) { bounds in
            // Resting controls do not build masks or compositing layers. The label keeps the same identity when pressed.
            if share > 0 {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                        .fill(DesignTokens.Colors.customerTint)
                        .mask {
                            if bounds.isEmpty { Color.white }
                            else {
                                Rectangle().fill(.white)
                                    .overlay {
                                        ZStack {
                                            ForEach(Array(bounds.enumerated()), id: \.offset) { _, bound in
                                                let rect = proxy[bound]
                                                Rectangle().fill(.white)
                                                    .frame(width: rect.width, height: rect.height)
                                                    .position(x: rect.midX, y: rect.midY)
                                            }
                                        }
                                        .blendMode(.destinationOut)
                                    }
                                    .compositingGroup()
                            }
                        }
                        .opacity(min(1, max(0, share)))
                        .blendMode(.multiply)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}
