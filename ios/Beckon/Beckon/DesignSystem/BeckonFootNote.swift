// One narrow note along the foot of a card (design, moved here in design when the groomer's photos and evidence needed it too): the one
// thing about the card that is out of the ordinary, in a single line that never wraps into a tag row. Amber is for what needs the
// person (a request that closes today, a photo with no fit notes, an answer that was negative); grey is for a wait or an ending.
// The note runs from edge to edge, so the card clips its content to its own corners.
import SwiftUI


struct BeckonFootNote: View {
    enum Tone: Equatable { case warm, calm }

    let text: String
    let systemImage: String
    var tone: Tone = .warm
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: systemImage)
            Text(text)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(DesignTokens.Typography.Expressive.chip)
        .foregroundStyle(tone == .warm ? DesignTokens.Colors.statusWarningText : DesignTokens.Colors.statusNeutralText)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone == .warm ? DesignTokens.Colors.statusWarningFill : DesignTokens.Colors.statusNeutralFill)
    }
}
