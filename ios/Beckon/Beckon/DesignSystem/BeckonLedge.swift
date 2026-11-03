import SwiftUI


/// Closed set of ledge surfaces for expressive (Tier L/M) screens; see `docs/01_product/LIVELY_UI_SPEC.md`.
/// A screen picks one and never assembles its own face, lip, radius or depth. Adding a case is a spec change (`highlight`, design).
enum BeckonLedgeSurface {
    /// White card with a quiet warm border and ledge. Tappable cards and notes.
    case card
    /// A card to notice first: the role's pale tint for its face, the role's own colour for its edge and ledge. For the few cards of
    /// a list that matter more than the rest (a request that names the groomer); when most of a list is one, none of them is.
    case highlight
    /// Circular icon control such as the bell.
    case round
    /// Active circular action; same geometry as round, with the role's action colors.
    case roundAction
    /// White button on a role-colored hero; Deep ledge. One per screen.
    case primary
    /// Small mint action pill or icon tile.
    case pill
    /// Dashed "add" slot.
    case dashed

    var face: Color {
        switch self {
        case .card, .round, .primary, .dashed: DesignTokens.Colors.surface
        case .pill, .roundAction: DesignTokens.Colors.customerFill
        case .highlight: DesignTokens.Colors.customerTint
        }
    }

    var lip: Color {
        switch self {
        case .card, .round: DesignTokens.Colors.border
        case .primary, .pill, .roundAction: DesignTokens.Colors.customerDeep
        case .dashed: DesignTokens.Colors.borderSoft
        case .highlight: DesignTokens.Colors.customerFill
        }
    }

    var edge: Color? {
        switch self {
        case .card, .round, .dashed: DesignTokens.Colors.border
        case .primary, .pill, .roundAction: nil
        case .highlight: DesignTokens.Colors.customerFill
        }
    }

    var radius: CGFloat {
        switch self {
        case .card, .dashed, .highlight: DesignTokens.CornerRadius.card
        case .round, .roundAction: DesignTokens.CornerRadius.round
        case .primary: DesignTokens.CornerRadius.ledgeButton
        case .pill: DesignTokens.CornerRadius.pill
        }
    }

    var depth: CGFloat {
        switch self {
        case .card, .dashed, .highlight: DesignTokens.Ledge.card
        case .round, .roundAction: DesignTokens.Ledge.control
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
/// `Motion.morph`, so the button stretches from the white card to the mint pill instead of fading (design). A dashed edge and a
/// solid edge are two strokes of which one is always clear, because a dash pattern cannot be tweened. The room under the face is the
/// same for every surface (`Ledge.room`) and only the lip inside it differs, so a button that changes surface changes nothing around
/// it: not the height of its row, and not the faces of its neighbours (design).
///
/// Touch-down acknowledges softly; a settled press or an accepted quick tap reaches the full press and buzzes once.
/// Scroll cancellation fades quietly; the existing guarded body still decides whether the action can fire.
/// Reduce Motion keeps the haptic and drops the travel.
struct BeckonLedgePressStyle: ButtonStyle {
    let surface: BeckonLedgeSurface
    var onPressChange: ((Bool) -> Void)?
    var animatesSurfaceChanges = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    init(_ surface: BeckonLedgeSurface = .card, onPressChange: ((Bool) -> Void)? = nil,
        animatesSurfaceChanges: Bool = true) {
        self.surface = surface
        self.onPressChange = onPressChange
        self.animatesSurfaceChanges = animatesSurfaceChanges
    }

    func makeBody(configuration: Configuration) -> some View {
        let surface = surface, onPressChange = onPressChange, reduceMotion = reduceMotion, isEnabled = isEnabled
        let animatesSurfaceChanges = animatesSurfaceChanges
        return BeckonPressEngine(isPressed: configuration.isPressed && isEnabled, haptic: .impact(weight: .medium)) { amount in
            let shape = RoundedRectangle(cornerRadius: surface.radius, style: .continuous)
            // A surface without an edge draws its edge in the colour of its face: invisible, and a colour the real edge can fade to.
            let edge = surface.edge ?? surface.face
            configuration.label
                .background {
                    ZStack {
                        shape.fill(surface.face)
                        shape.fill(surface.pressedFace).opacity(min(1, max(0, amount)))
                    }
                }
                .overlay {
                    ZStack {
                        shape.strokeBorder(edge, lineWidth: DesignTokens.Ledge.edgeWidth)
                            .opacity(surface.isDashed ? 0 : 1)
                        shape.strokeBorder(edge, style: StrokeStyle(lineWidth: DesignTokens.Ledge.dashedEdgeWidth,
                            dash: DesignTokens.Ledge.dash))
                            .opacity(surface.isDashed ? 1 : 0)
                    }
                }
                .offset(y: reduceMotion ? 0 : surface.depth * amount)
                .background { shape.fill(surface.lip).offset(y: surface.depth) }
                .padding(.bottom, DesignTokens.Ledge.room)
                .contentShape(Rectangle())
                // The look turning into another look; the press itself is animated by the engine.
                .animation(animatesSurfaceChanges ? (reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.morph) : nil, value: surface)
                .onChange(of: amount >= 0.99) { _, now in onPressChange?(now) }
                .opacity(isEnabled ? 1 : 0.5)
        }
    }
}


/// The ledge button for every `Button` and `NavigationLink`: the ledge look above, plus the platform's rule that a drag is
/// not a tap (see `BeckonGuardedButtonBody`). Same initializer as before, so call sites do not change.
struct BeckonLedgeButtonStyle: PrimitiveButtonStyle {
    let surface: BeckonLedgeSurface
    var onPressChange: ((Bool) -> Void)?
    var animatesSurfaceChanges = true

    init(_ surface: BeckonLedgeSurface = .card, onPressChange: ((Bool) -> Void)? = nil,
        animatesSurfaceChanges: Bool = true) {
        self.surface = surface
        self.onPressChange = onPressChange
        self.animatesSurfaceChanges = animatesSurfaceChanges
    }

    func makeBody(configuration: Configuration) -> some View {
        BeckonGuardedButtonBody(configuration: configuration,
            style: BeckonLedgePressStyle(surface, onPressChange: onPressChange, animatesSurfaceChanges: animatesSurfaceChanges))
    }
}
