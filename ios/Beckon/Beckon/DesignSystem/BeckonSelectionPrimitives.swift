import SwiftUI

struct BeckonSelectionCard<Content: View>: View {
    let isSelected: Bool
    let isInvalid: Bool
    let accent: BeckonRoleAccent
    let action: () -> Void
    let content: Content

    init(
        isSelected: Bool,
        isInvalid: Bool = false,
        accent: BeckonRoleAccent,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.isInvalid = isInvalid
        self.accent = accent
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.Layout.surfaceInset)
                .background(
                    isSelected
                        ? accent.tint
                        : DesignTokens.Colors.surface
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.card,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.card,
                        style: .continuous
                    )
                    .stroke(
                        isInvalid
                            ? DesignTokens.Colors.statusErrorText
                            : (isSelected ? accent.darkColor : DesignTokens.Colors.border),
                        lineWidth: isSelected || isInvalid ? 2 : 1
                    )
                }
                .contentShape(Rectangle())
                .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
    }
}




/// A ring that becomes a tick, the choice mark of a card, a row or a button (S-066). It is one drawing in both states, not two
/// symbols that trade places: the ring stays where it is, a disc grows out of its centre and the tick is drawn into the disc stroke
/// by stroke, so choosing reads as one movement and not as a fade (the system's `circle` and `checkmark.circle.fill` are different
/// glyphs, and swapping them can only cross-fade). It animates itself under `Motion.morph` whenever `isOn` changes, wherever it sits.
struct BeckonTickCircle: View {
    let isOn: Bool
    /// The ring while it is empty.
    var off: Color = DesignTokens.Colors.border
    /// The disc once it is chosen.
    var on: Color = DesignTokens.Colors.customerInk
    /// The tick: the colour of the face the mark sits on.
    var tick: Color = DesignTokens.Colors.customerFill
    @ScaledMetric private var diameter: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isOn: Bool, size: CGFloat = 28, off: Color = DesignTokens.Colors.border,
         on: Color = DesignTokens.Colors.customerInk, tick: Color = DesignTokens.Colors.customerFill) {
        self.isOn = isOn
        self.off = off
        self.on = on
        self.tick = tick
        _diameter = ScaledMetric(wrappedValue: size, relativeTo: .title)
    }

    var body: some View {
        ZStack {
            Circle().strokeBorder(off, lineWidth: max(2, diameter * 0.09))
            // Scale 0 and not 0.01: a hundredth of a disc is still a speck in the middle of the empty ring.
            Circle().fill(on).scaleEffect(isOn ? 1 : 0)
            BeckonTickShape()
                .trim(from: 0, to: isOn ? 1 : 0)
                .stroke(tick, style: StrokeStyle(lineWidth: max(2, diameter * 0.1), lineCap: .round, lineJoin: .round))
                .padding(diameter * 0.27)
        }
        .frame(width: diameter, height: diameter)
        .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.morph, value: isOn)
        .accessibilityHidden(true)
    }
}


/// The tick of `BeckonTickCircle`: one stroke, short leg then long leg, so `trim` draws it in the way a hand would.
struct BeckonTickShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.08))
        return path
    }
}
