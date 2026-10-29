// Steps 1 (Pet) and 2 (Service) of the request wizard, redesigned from what each choice is for (S-044).
// The pet card is the pet: name, breed and weight (the coat and temperament chips it had were the groomer's business, not the owner's, S-066).
// The services are not six equal things: two packages, three single services and a custom request that needs words later.
import SwiftUI


// MARK: Step 1, the pet

/// One pet to choose. A ledge button like the day and time tiles of step 3: mint when chosen, with a tick or an empty ring.
struct CustomerRequestPetChoiceCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let pet: CustomerPet
    let petPhotoData: Data?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.lg))
        Button(action: action) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                layout {
                    BeckonPetAvatar(
                        data: petPhotoData,
                        systemImage: BeckonPetPresentation.symbol(for: pet.displaySpecies),
                        width: 72, height: 72,
                        cornerRadius: DesignTokens.CornerRadius.input
                    )
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(pet.name)
                            .font(DesignTokens.Typography.Expressive.title)
                            .accessibilityIdentifier("pet.\(pet.id.uuidString).name")
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Text(breedText)
                                .accessibilityIdentifier("pet.\(pet.id.uuidString).breed")
                            if let weight = weightText {
                                Text("·").accessibilityHidden(true)
                                Text(weight)
                                    .accessibilityIdentifier("pet.\(pet.id.uuidString).weight")
                            }
                        }
                        .font(DesignTokens.Typography.Expressive.supporting)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if !typeSize.isAccessibilitySize {
                        BeckonTickCircle(isOn: isSelected)
                    }
                }
            }
            .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textPrimary)
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        }
        .buttonStyle(BeckonLedgeButtonStyle(isSelected ? .pill : .card))
        .padding(.bottom, isSelected ? DesignTokens.Ledge.card - DesignTokens.Ledge.pill : DesignTokens.Spacing.none)
        .accessibilityIdentifier("customer.requests.wizard.pet.\(pet.species.lowercased()).\(pet.id.uuidString)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var breedText: String {
        let breed = pet.displayBreed?.trimmingCharacters(in: .whitespacesAndNewlines)
        return breed?.isEmpty == false ? breed ?? pet.displaySpecies : pet.displaySpecies
    }

    private var weightText: String? {
        pet.weightLbs.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) lbs" }
    }
}


/// "Add a new pet" at the end of the pet choice: the kit's dashed ledge surface, so it reads as an empty slot like the Home one.
struct CustomerRequestAddPetButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "plus")
                    .font(DesignTokens.Typography.Expressive.glyph)
                Text("Add a new pet")
                    .font(DesignTokens.Typography.Expressive.emphasis)
            }
            .foregroundStyle(DesignTokens.Colors.customerDeep)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.dashed))
        .accessibilityIdentifier("customer.requests.wizard.add-pet")
    }
}


// MARK: Step 2, the service

/// The services as the choice they are: whole packages, single services, and the one that needs words.
enum CustomerRequestServiceGroup: CaseIterable, Identifiable {
    case packages, singles, other

    var id: Self { self }

    var title: String {
        switch self {
        case .packages: "Packages"
        case .singles: "Single services"
        case .other: "Something else"
        }
    }

    var services: [CustomerRequestServiceOption] {
        switch self {
        case .packages: [.fullGroom, .bathAndBrush]
        case .singles: [.haircutOnly, .nailTrim, .deShedding]
        case .other: CustomerRequestServiceOption.allCases.filter { ![.fullGroom, .bathAndBrush, .haircutOnly, .nailTrim, .deShedding].contains($0) }
        }
    }
}


/// One service to choose: its own symbol, its name and what it covers, a tick or an empty ring.
struct CustomerRequestServiceChoiceRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let option: CustomerRequestServiceOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))
        Button(action: action) {
            layout {
                DesignIconDisc(systemImage: symbol, size: .touch, font: DesignTokens.Typography.Expressive.glyph)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(option.title)
                        .font(DesignTokens.Typography.Expressive.headline)
                    // What a package includes is worth a line; "Nail trim" does not need "Quick clip and file".
                    if option == .fullGroom || option == .bathAndBrush {
                        Text(option.subtitle)
                            .font(DesignTokens.Typography.Expressive.supporting)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                if !typeSize.isAccessibilitySize {
                    BeckonTickCircle(isOn: isSelected)
                }
            }
            .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        }
        .buttonStyle(BeckonLedgeButtonStyle(isSelected ? .pill : .card))
        .padding(.bottom, isSelected ? DesignTokens.Ledge.card - DesignTokens.Ledge.pill : DesignTokens.Spacing.none)
        .accessibilityIdentifier("customer.requests.wizard.service.\(option.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var symbol: String {
        switch option {
        case .fullGroom: "sparkles"
        case .bathAndBrush: "shower.fill"
        case .haircutOnly: "scissors"
        case .nailTrim: "pawprint.fill"
        case .deShedding: "wind"
        case .customRequest: "pencil.and.list.clipboard"
        }
    }
}


/// A group of services under its small heading; one block of the step.
struct CustomerRequestServiceGroupBlock: View {
    let group: CustomerRequestServiceGroup
    let selected: CustomerRequestServiceOption?
    let choose: (CustomerRequestServiceOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if group != .other {
                Text(group.title)
                    .font(DesignTokens.Typography.Expressive.label)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(group.services) { option in
                CustomerRequestServiceChoiceRow(option: option, isSelected: selected == option) { choose(option) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
