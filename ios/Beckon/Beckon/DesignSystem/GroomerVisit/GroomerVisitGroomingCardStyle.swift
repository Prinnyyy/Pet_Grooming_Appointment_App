import SwiftUI

struct GroomerVisitGroomingCardStyle: PrimitiveButtonStyle {
    let needsAction: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let surface: BeckonLedgeSurface = needsAction ? .highlight : .card
        return BeckonGuardedButtonBody(configuration: configuration, style: BeckonPressActionLook { button in
            BeckonPressEngine(isPressed: button.isPressed && isEnabled, haptic: .impact(weight: .medium)) { amount in
                button.label
                    .modifier(BeckonPressFace(face: BeckonLedgeSurface.card.face, pressedFace: BeckonLedgeSurface.card.face,
                        lip: surface.lip, edge: surface.edge, depth: surface.depth, radius: surface.radius, amount: amount))
                    .padding(.bottom, DesignTokens.Ledge.room - surface.depth)
                    .opacity(isEnabled ? 1 : 0.5)
            }
        })
    }
}
