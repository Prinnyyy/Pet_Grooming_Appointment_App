import SwiftUI

enum BeckonGroomingLocationPerspective {
    case customer
    case groomer
}

struct BeckonGroomingLocationModePresentation: Equatable {
    static let detailSectionTitle = "Preferred Time and Service Location"
    static let detailSectionSubtitle = "Preferred timing and where grooming will take place."
    static let detailFieldTitle = "Service Location"

    let title: String
    let leadingIcon: String?

    init(
        mode: GroomingLocationMode,
        perspective: BeckonGroomingLocationPerspective
    ) {
        leadingIcon = nil

        switch (mode, perspective) {
        case (.groomerComesToCustomer, .customer):
            title = "My Home"
        case (.customerComesToGroomer, .customer):
            title = "Groomer's Place"
        case (.groomerComesToCustomer, .groomer):
            title = "Customer's Home"
        case (.customerComesToGroomer, .groomer):
            title = "My Place"
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

struct BeckonGroomingLocationModeSelector: View {
    let selection: Set<GroomingLocationMode>
    let selectionPolicy: BeckonGroomingLocationSelectionPolicy
    let perspective: BeckonGroomingLocationPerspective
    let accent: BeckonRoleAccent
    let onSelectionChange: (Set<GroomingLocationMode>) -> Void

    var body: some View {
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
                        Text(presentation.title)
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(DesignTokens.Typography.status)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .frame(width: 34, height: 34)
                                .background(accent.color.opacity(0.42))
                                .clipShape(Circle())
                        }
                    }
                }
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
            }
        }
    }
}
