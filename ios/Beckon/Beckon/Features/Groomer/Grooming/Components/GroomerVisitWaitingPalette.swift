import SwiftUI

/// Explicit responder identity: never use role-adaptive customer… colors here.
struct GroomerVisitWaitingPalette {
    let responder: BeckonRole
    private var customer: Bool { responder == .customer }
    private static func color(_ hex: UInt) -> Color {
        Color(.sRGB, red: Double((hex >> 16) & 255) / 255,
              green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
    var fill: Color { Self.color(customer ? DesignTokens.Palette.mintTint : DesignTokens.Palette.coralTint) }
    var edge: Color { Self.color(customer ? DesignTokens.Palette.mintFill : DesignTokens.Palette.coralFill) }
    var icon: Color { Self.color(customer ? DesignTokens.Palette.mintDeep : DesignTokens.Palette.coralDeep) }
    var text: Color { Self.color(customer ? DesignTokens.Palette.mintInk : DesignTokens.Palette.coralInk) }
}

struct GroomerVisitWaitingFootNote: View {
    let text: String
    let responder: BeckonRole
    var body: some View {
        GroomerVisitStatusFootNote(text: text, systemImage: "ellipsis", tone: .waitingFor(responder))
    }
}
