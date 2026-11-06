import SwiftUI

struct GroomerVisitPetProfileButton: View {
    let pet: GroomingRequestPetSnapshot
    @Binding var selection: GroomingRequestPetSnapshot?

    var body: some View {
        Self.control { selection = pet }
            .accessibilityLabel("Pet profile, " + pet.name)
            .accessibilityHint("View the details shared by the customer.")
            .accessibilityIdentifier("groomerVisit.request.pet.open")
    }

    private static func control(action: @escaping () -> Void) -> some View {
        let halfLedge = DesignTokens.Ledge.control / 2
        return GroomerVisitNavigationButton(action: action) { Label("Pet profile", systemImage: "pawprint.fill") }
            .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer, isFullWidth: false))
            // Centre the button face with the pet's name and service, accounting for the ledge underneath.
            .alignmentGuide(VerticalAlignment.center) { $0[VerticalAlignment.center] - halfLedge }
    }

    static var placeholder: some View {
        control {}.hidden()
            .overlay {
                DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.ledgeButton)
                    .padding(.bottom, DesignTokens.Ledge.control)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Reads the pet information attached to the request, grouped like the customer's pet form.
struct GroomerVisitRequestPetProfile: View {
    typealias Photo = GroomerPetCard.Photo
    let pet: GroomingRequestPetSnapshot
    let photos: [Photo]
    @State private var inspecting: Photo?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var portrait: Photo? {
        photos.first(where: { $0.data != nil })
    }

    var body: some View {
        let age = ageLine
        DesignPage {
            identity
            if weight != nil || size != nil || age != nil {
                DesignSection(title: "Size and age", systemImage: "ruler.fill", spacing: GroomerVisitDetailRowLayout.rowSpacing) {
                    GroomerVisitDetailRowGroup {
                        if let weight { GroomerVisitRequestFactRow(systemImage: "scalemass", title: "Weight", value: weight) }
                        if let size { GroomerVisitRequestFactRow(systemImage: "ruler", title: "Size", value: size) }
                        if let age { GroomerVisitRequestFactRow(systemImage: "calendar", title: "Age", value: age) }
                    }
                }
            }
            if temperament != nil || pet.mattingConfirmed != nil || clean(pet.medicalNotes) != nil || clean(pet.groomingNotes) != nil {
                DesignSection(title: "Care notes", systemImage: "heart.text.square.fill", spacing: GroomerVisitDetailRowLayout.rowSpacing) {
                    GroomerVisitDetailRowGroup {
                        if let temperament { GroomerVisitRequestFactRow(systemImage: "face.smiling", title: "Temperament", value: temperament) }
                        if let matting = pet.mattingConfirmed {
                            GroomerVisitRequestFactRow(systemImage: "scribble", title: "Coat matting", value: matting ? "Yes" : "No")
                        }
                        if let note = clean(pet.medicalNotes) {
                            GroomerVisitRequestFactRow(systemImage: "cross.case", title: "Medical notes", value: note)
                        }
                        if let note = clean(pet.groomingNotes) {
                            GroomerVisitRequestFactRow(systemImage: "note.text", title: "Grooming notes", value: note)
                        }
                    }
                }
            }
            let additionalPhotos = photos.filter { $0.id != portrait?.id && $0.data != nil }
            if !additionalPhotos.isEmpty {
                DesignSection(title: "Photos", systemImage: "photo.on.rectangle") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(additionalPhotos) { photo in
                                Button { inspecting = photo } label: {
                                    BeckonPetAvatar(data: photo.data, systemImage: "photo", width: 64, height: 64,
                                        cornerRadius: DesignTokens.CornerRadius.inset)
                                }
                                .buttonStyle(BeckonGuardedPlainButtonStyle())
                                .accessibilityLabel("View photo: " + photo.label)
                            }
                        }
                    }.beckonTracksScroll()
                }
            }
        }
        .navigationTitle("Pet profile")
        .navigationBarTitleDisplayMode(.inline)
        .groomerVisitDetailPresentation()
        .beckonSheet(item: $inspecting) { photo in
            if let data = photo.data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit()
                    .padding(DesignTokens.Spacing.lg)
                    .presentationDragIndicator(.visible)
                    .accessibilityLabel(photo.label)
            }
        }
    }

    private var identity: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.lg))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.lg))
        return layout {
            avatar
            // Equal gaps between the name, species/breed and chip; the chip keeps its own internal padding.
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(pet.name).font(DesignTokens.Typography.Expressive.title)
                    .fixedSize(horizontal: false, vertical: true)
                let species = CustomerPetSpecies(storedValue: pet.species)?.title ?? pet.species
                let breed = clean(pet.breed).map { CustomerPetBreed(storedValue: $0)?.title ?? $0 }
                Text([species, breed].compactMap { $0 }.joined(separator: " · "))
                    .font(DesignTokens.Typography.Expressive.supporting)
                    .fixedSize(horizontal: false, vertical: true)
                if let coat = clean(pet.coatType) {
                    let title = CustomerPetCoatType(storedValue: coat)?.title ?? coat
                    BeckonMetaChip(text: title, systemImage: "scribble.variable")
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Coat type, " + title)
                }
            }
            .foregroundStyle(DesignTokens.Colors.customerInk)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .designBanner()
    }

    private var avatar: some View {
        BeckonPetAvatar(data: portrait?.data, systemImage: BeckonPetPresentation.symbol(for: pet.species),
            width: 80, height: 80, cornerRadius: 40)
            .overlay(Circle().strokeBorder(DesignTokens.Colors.surface, lineWidth: 3))
            .accessibilityHidden(true)
    }

    private var weight: String? {
        guard let value = pet.weightLbs, value.isFinite, value > 0 else { return nil }
        return value.formatted(.number.precision(.fractionLength(0...2))) + " lb"
    }

    private var size: String? { clean(pet.size).map { CustomerPetSizeCode(storedValue: $0)?.title ?? $0 } }

    private var temperament: String? {
        clean(pet.temperament).map { CustomerPetTemperament(storedValue: $0)?.title ?? $0 }
    }

    private var ageLine: String? {
        guard let raw = clean(pet.birthday),
              let date = try? Date(raw, strategy: .iso8601.year().month().day()), date <= .now else { return nil }
        return pet.beckonAgeLine
    }

    private func clean(_ text: String?) -> String? {
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
