import SwiftUI

/// One price row for editing, sent offers and booked appointments.
struct GroomerVisitOfferPriceHeader<Amount: View, Accessory: View>: View {
    var caption = "Price estimate"
    var editPrice: (() -> Void)? = nil
    @ViewBuilder let amount: (CGFloat) -> Amount
    @ViewBuilder let accessory: () -> Accessory

    @ScaledMetric(relativeTo: .largeTitle) private var pointSize: CGFloat = 40
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: GroomerVisitDetailRowLayout.iconGap) {
                DesignIconDisc(systemImage: "tag.fill")
                    .frame(width: GroomerVisitDetailRowLayout.iconSize, height: GroomerVisitDetailRowLayout.iconSize)
                    .accessibilityHidden(true)
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: GroomerVisitDetailRowLayout.accessoryGap))
                layout {
                    VStack(alignment: .leading, spacing: GroomerVisitDetailRowLayout.labelSpacing) {
                        Text(caption)
                            .font(DesignTokens.Typography.Expressive.chip)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                        amountLine
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if editPrice != nil {
                        accessory().groomerVisitKeyboardInputRegion()
                            .frame(width: GroomerVisitDetailRowLayout.accessoryWidth)
                    } else {
                        accessory()
                    }
                }
            }
            .padding(GroomerVisitDetailRowLayout.cardRowInsets(isFirst: true))
            DesignRowDivider().padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .background(DesignTokens.Colors.surface)
    }

    @ViewBuilder private var amountLine: some View {
        let line = HStack(alignment: .firstTextBaseline, spacing: 0) {
            currencyMark
            amount(pointSize)
        }
        .font(DesignTokens.Typography.Expressive.offerAmount(size: pointSize))
        .foregroundStyle(DesignTokens.Colors.textPrimary)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget, alignment: .leading)

        if editPrice != nil {
            line.groomerVisitKeyboardInputRegion()
                .beckonKeyboardFocusTarget(GroomerOfferFocusTarget.price.rawValue)
        } else { line }
    }

    @ViewBuilder private var currencyMark: some View {
        let mark = Text("$").fixedSize().accessibilityHidden(true)
        if let editPrice { mark.onTapGesture(perform: editPrice) }
        else { mark }
    }
}

struct GroomerVisitOfferPriceCaption: View {
    var title = "Price estimate"
    var body: some View {
        Text(title)
            .font(DesignTokens.Typography.Expressive.chip)
            .foregroundStyle(DesignTokens.Colors.groomerDeep)
    }
}
