// The small part the groomer's Requests pages share (design, cut down in design when the cards became one row): the pet's face.
// Colour comes from the role (`.environment(\.beckonRole, .groomer)` on the shell), so
// nothing here names coral.
import SwiftUI


// MARK: Pet face

/// The pet's picture, or its species on the grey disc when there is no photo, ringed in the role's colour.
struct GroomerPetAvatar: View {
    let species: String
    var data: Data?
    var size: CGFloat = DesignTokens.Metrics.petAvatar

    var body: some View {
        BeckonPetAvatar(data: data, systemImage: BeckonPetPresentation.symbol(for: species),
            width: size, height: size, cornerRadius: size / 2)
            .overlay(Circle().strokeBorder(DesignTokens.Colors.customerFill, lineWidth: DesignTokens.Ledge.edgeWidth + 1))
            .accessibilityHidden(true)
    }
}
