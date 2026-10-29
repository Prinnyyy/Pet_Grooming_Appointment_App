import SwiftUI


enum BeckonGroomingLocationPerspective {
    case customer
    case groomer
}


struct BeckonGroomingLocationModePresentation: Equatable {
    static let detailSectionTitle = "Preferred time and service location"
    static let detailSectionSubtitle = "Preferred timing and where grooming will take place."
    static let detailFieldTitle = "Service location"

    let title: String
    let supportingText: String
    let leadingIcon: String?

    init(
        mode: GroomingLocationMode,
        perspective: BeckonGroomingLocationPerspective
    ) {
        leadingIcon = nil

        switch (mode, perspective) {
        case (.groomerComesToCustomer, .customer):
            title = "My home"
            supportingText = "A mobile groomer comes to your address."
        case (.customerComesToGroomer, .customer):
            title = "Groomer's place"
            supportingText = "You bring your pet to the groomer's location."
        case (.groomerComesToCustomer, .groomer):
            title = "Customer's home"
            supportingText = "You travel to the customer's address."
        case (.customerComesToGroomer, .groomer):
            title = "My place"
            supportingText = "The customer brings their pet to your location."
        }
    }
}


enum BeckonGroomingLocationSelectionPolicy {
    case single
    case multiple

    func updatedSelection(
        _ selection: Set<GroomingLocationMode>,
        toggling mode: GroomingLocationMode
    ) -> Set<GroomingLocationMode> {
        switch self {
        case .single:
            [mode]
        case .multiple:
            if selection.contains(mode) {
                selection.subtracting([mode])
            } else {
                selection.union([mode])
            }
        }
    }
}


/// Two tiles side by side (stacked at accessibility sizes) and the sentence of the chosen one underneath: where the service
/// happens is a choice between two places, not two paragraphs. The selected tile is the mint ledge with a check.
struct BeckonGroomingLocationModeSelector: View {
    let selection: Set<GroomingLocationMode>
    let selectionPolicy: BeckonGroomingLocationSelectionPolicy
    let perspective: BeckonGroomingLocationPerspective
    let accent: BeckonRoleAccent
    /// The sentence of the chosen tile under the tiles. Off in the request wizard: the two tiles already say it (S-066).
    var showsSentence = true
    let onSelectionChange: (Set<GroomingLocationMode>) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    @ViewBuilder var body: some View {
        if perspective == .customer { customerBody } else { groomerBody }
    }

    private var customerBody: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: DesignTokens.Spacing.sm))
                : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))
            layout {
                ForEach(GroomingLocationMode.allCases) { mode in tile(mode) }
            }
            if showsSentence {
                ForEach(GroomingLocationMode.allCases.filter { selection.contains($0) }) { mode in
                    Text(BeckonGroomingLocationModePresentation(mode: mode, perspective: perspective).supportingText)
                        .designSupportingText()
                }
            }
        }
    }

    private func tile(_ mode: GroomingLocationMode) -> some View {
        let isSelected = selection.contains(mode)
        let presentation = BeckonGroomingLocationModePresentation(mode: mode, perspective: perspective)
        return Button {
            onSelectionChange(selectionPolicy.updatedSelection(selection, toggling: mode))
        } label: {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: mode == .groomerComesToCustomer ? "house.fill" : "storefront.fill")
                    .font(DesignTokens.Typography.Expressive.glyphLarge)
                    .accessibilityHidden(true)
                Text(presentation.title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 88)
            .overlay(alignment: .topTrailing) {
                // Always there, empty until chosen: the disc grows and the tick is drawn, instead of a badge fading in.
                BeckonTickCircle(isOn: isSelected, size: 18, off: .clear, on: accent.deep)
                    .padding(DesignTokens.Spacing.sm)
            }
        }
        .buttonStyle(BeckonLedgeButtonStyle(isSelected ? .pill : .card))
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(presentation.supportingText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    private var groomerBody: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(GroomingLocationMode.allCases) { mode in
                let isSelected = selection.contains(mode)
                let presentation = BeckonGroomingLocationModePresentation(
                    mode: mode,
                    perspective: perspective
                )

                BeckonSelectionCard(
                    isSelected: isSelected,
                    accent: accent
                ) {
                    onSelectionChange(
                        selectionPolicy.updatedSelection(selection, toggling: mode)
                    )
                } content: {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(presentation.title)
                                .font(DesignTokens.Typography.body.weight(.bold))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)

                            Text(presentation.supportingText)
                                .font(DesignTokens.Typography.supporting)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(DesignTokens.Typography.status)
                                .foregroundStyle(accent.deep)
                                .frame(width: 34, height: 34)
                                .background(accent.tint)
                                .clipShape(Circle())
                        }
                    }
                }
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
            }
        }
    }
}
