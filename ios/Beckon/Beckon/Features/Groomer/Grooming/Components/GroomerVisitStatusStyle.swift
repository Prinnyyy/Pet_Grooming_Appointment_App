import SwiftUI

/// The PDF's semantic palette. Bubbles, explanation panels and list strips share this owner.
enum GroomerVisitStatusTone {
    case ready, checking, action, success, declined, quiet
    case waitingFor(BeckonRole)
    private typealias Ink = DesignTokens.Colors

    var colors: (icon: Color, text: Color, fill: Color, edge: Color) {
        switch self {
        case .ready: (Ink.groomerDeep, Ink.groomerInk, Ink.groomerTint, Ink.groomerFill)
        case .checking: (Ink.statusInfoText, Ink.textPrimary, Ink.statusInfoFill, Ink.statusInfoBorder)
        case .action: (Ink.statusWarningText, Ink.textPrimary, Ink.statusWarningFill, Ink.statusWarningBorder)
        case .waitingFor(let responder):
            (GroomerVisitWaitingPalette(responder: responder).icon, GroomerVisitWaitingPalette(responder: responder).text,
             GroomerVisitWaitingPalette(responder: responder).fill, GroomerVisitWaitingPalette(responder: responder).edge)
        case .success: (Ink.statusSuccessText, Ink.textPrimary, Ink.statusSuccessFill, Ink.statusSuccessBorder)
        case .declined, .quiet: (Ink.statusNeutralText, Ink.textPrimary, Ink.statusNeutralFill, Ink.statusNeutralBorder)
        }
    }
}

struct GroomerVisitStatusFootNote: View {
    let text: String
    let systemImage: String
    let tone: GroomerVisitStatusTone
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let colors = tone.colors
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: systemImage).foregroundStyle(colors.icon)
            Text(text).foregroundStyle(colors.text)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(DesignTokens.Typography.Expressive.chip)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.fill)
    }
}
