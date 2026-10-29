import SwiftUI


/// Closed set of ledge surfaces for expressive (Tier L/M) screens; see `docs/01_product/LIVELY_UI_SPEC.md`.
/// A screen picks one and never assembles its own face, lip, radius or depth. Adding a case is a spec change.
enum BeckonLedgeSurface {
    /// White card with a quiet warm border and ledge. Tappable cards and notes.
    case card
    /// Circular icon control such as the bell.
    case round
    /// White button on a role-colored hero; Deep ledge. One per screen.
    case primary
    /// Small mint action pill or icon tile.
    case pill
    /// Dashed "add" slot.
    case dashed

    var face: Color {
        switch self {
        case .card, .round, .primary, .dashed: DesignTokens.Colors.surface
        case .pill: DesignTokens.Colors.customerFill
        }
    }

    var lip: Color {
        switch self {
        case .card, .round: DesignTokens.Colors.border
        case .primary, .pill: DesignTokens.Colors.customerDeep
        case .dashed: DesignTokens.Colors.borderSoft
        }
    }

    var edge: Color? {
        switch self {
        case .card, .round, .dashed: DesignTokens.Colors.border
        case .primary, .pill: nil
        }
    }

    var radius: CGFloat {
        switch self {
        case .card, .dashed: DesignTokens.CornerRadius.card
        case .round: DesignTokens.CornerRadius.round
        case .primary: DesignTokens.CornerRadius.ledgeButton
        case .pill: DesignTokens.CornerRadius.pill
        }
    }

    var depth: CGFloat {
        switch self {
        case .card, .dashed: DesignTokens.Ledge.card
        case .round: DesignTokens.Ledge.control
        case .primary: DesignTokens.Ledge.button
        case .pill: DesignTokens.Ledge.pill
        }
    }

    var isDashed: Bool { self == .dashed }
}


/// Static ledge for content that is not itself a button: face, optional edge, opaque lip.
private struct BeckonLedgeModifier: ViewModifier {
    let surface: BeckonLedgeSurface

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: surface.radius, style: .continuous)
        content
            .background(shape.fill(surface.face))
            .overlay {
                if let edge = surface.edge { shape.strokeBorder(edge, lineWidth: DesignTokens.Ledge.edgeWidth) }
            }
            .background { shape.fill(surface.lip).offset(y: surface.depth) }
            .padding(.bottom, surface.depth)
    }
}


extension View {
    func beckonLedge(_ surface: BeckonLedgeSurface = .card) -> some View {
        modifier(BeckonLedgeModifier(surface: surface))
    }
}


/// The look of a ledge button and nothing else. Use `BeckonLedgeButtonStyle` for buttons and links; use this one only
/// where the control is not a plain button (a `Menu`, a `PhotosPicker`) and a guarded tap cannot be applied.
///
/// A button whose surface changes with its state (`isSelected ? .pill : .card`) does not swap one look for another: the face
/// colour, the corner radius, the lip and the edge are the same pieces in every surface and only their values change, under
/// `Motion.morph`, so the button stretches from the white card to the mint pill instead of fading (S-066). A dashed edge and a
/// solid edge are two strokes of which one is always clear, because a dash pattern cannot be tweened.
///
/// Physical press: the face sinks into its lip, then springs back with overshoot, with a medium haptic. The press starts only
/// once the touch has settled (see `BeckonSettledPress`), so scrolling over buttons neither sinks them nor buzzes.
/// Reduce Motion keeps the haptic and drops the travel.
struct BeckonLedgePressStyle: ButtonStyle {
    let surface: BeckonLedgeSurface
    var onPressChange: ((Bool) -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    init(_ surface: BeckonLedgeSurface = .card, onPressChange: ((Bool) -> Void)? = nil) {
        self.surface = surface
        self.onPressChange = onPressChange
    }

    func makeBody(configuration: Configuration) -> some View {
        // Read once here: the content closure runs later, inside the wrapper's body.
        let surface = surface, onPressChange = onPressChange, reduceMotion = reduceMotion, isEnabled = isEnabled
        return BeckonSettledPress(isPressed: configuration.isPressed) { pressed in
            let shape = RoundedRectangle(cornerRadius: surface.radius, style: .continuous)
            // A surface without an edge draws its edge in the colour of its face: invisible, and a colour the real edge can fade to.
            let edge = surface.edge ?? surface.face
            configuration.label
                .background(shape.fill(surface.face))
                .overlay {
                    ZStack {
                        shape.strokeBorder(edge, lineWidth: DesignTokens.Ledge.edgeWidth)
                            .opacity(surface.isDashed ? 0 : 1)
                        shape.strokeBorder(edge, style: StrokeStyle(lineWidth: DesignTokens.Ledge.dashedEdgeWidth,
                            dash: DesignTokens.Ledge.dash))
                            .opacity(surface.isDashed ? 1 : 0)
                    }
                }
                .offset(y: pressed && !reduceMotion ? surface.depth : 0)
                .background { shape.fill(surface.lip).offset(y: surface.depth) }
                .padding(.bottom, surface.depth)
                .contentShape(Rectangle())
                // The look turning into another look. Under the press animation below, so a press is still the press spring.
                .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.morph, value: surface)
                .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.press, value: pressed)
                .sensoryFeedback(.impact(weight: .medium), trigger: pressed) { _, now in now }
                .onChange(of: pressed) { _, now in onPressChange?(now) }
                .opacity(isEnabled ? 1 : 0.5)
        }
    }
}


/// The ledge button for every `Button` and `NavigationLink`: the ledge look above, plus the platform's rule that a drag is
/// not a tap (see `BeckonGuardedButtonBody`). Same initializer as before, so call sites do not change.
struct BeckonLedgeButtonStyle: PrimitiveButtonStyle {
    let surface: BeckonLedgeSurface
    var onPressChange: ((Bool) -> Void)?

    init(_ surface: BeckonLedgeSurface = .card, onPressChange: ((Bool) -> Void)? = nil) {
        self.surface = surface
        self.onPressChange = onPressChange
    }

    func makeBody(configuration: Configuration) -> some View {
        BeckonGuardedButtonBody(configuration: configuration,
            style: BeckonLedgePressStyle(surface, onPressChange: onPressChange))
    }
}
