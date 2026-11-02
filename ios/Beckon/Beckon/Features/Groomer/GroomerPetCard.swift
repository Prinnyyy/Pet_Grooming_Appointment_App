// What a groomer reads about a pet before answering a request or starting a booking (design, shared by both pages in design): who the
// pet is and how it is to handle, the customer's notes for the visit, and what the owner said about its health. Rows appear when
// there is something to say.
import SwiftUI


struct GroomerPetCard: View {
    /// A photo of the request, as the store hands it over.
    struct Photo: Identifiable {
        let id: String
        let data: Data?
        let label: String
    }

    let pet: GroomingRequestPetSnapshot
    /// What the customer wrote for this visit.
    var visitNotes: String?
    var photos: [Photo] = []
    var identifier = "groomer.booking.pet"

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "About \(pet.name)", systemImage: "pawprint.fill")
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                BeckonFlowLayout(spacing: DesignTokens.Spacing.sm, rowSpacing: DesignTokens.Spacing.sm) {
                    BeckonMetaChip(text: pet.breed ?? pet.species, systemImage: "pawprint.fill")
                    if let build { BeckonMetaChip(text: build, systemImage: "scalemass.fill") }
                    if let age = pet.beckonAgeLine { BeckonMetaChip(text: age, systemImage: "birthday.cake.fill") }
                    if let coat = pet.coatType, !coat.isEmpty { BeckonMetaChip(text: coat, systemImage: "scribble.variable") }
                }
                if let text = clean(pet.temperament) {
                    DesignFactRow(systemImage: "face.smiling", title: "Temperament", value: text)
                }
                if let text = clean(visitNotes) {
                    DesignFactRow(systemImage: "text.bubble.fill", title: "From the customer, for this visit", value: text)
                }
                if let text = clean(pet.groomingNotes) {
                    DesignFactRow(systemImage: "note.text", title: "Grooming notes", value: text)
                }
                if let text = clean(pet.medicalNotes) {
                    DesignFactRow(systemImage: "cross.case.fill", title: "Health notes", value: text, tone: .caution)
                }
                if !photos.isEmpty { photoStrip }
            }
            .designCardBody()
        }
        .accessibilityIdentifier(identifier)
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(photos) { photo in
                    BeckonModuleImage(data: photo.data) {
                        Image(systemName: "photo")
                            .font(DesignTokens.Typography.Expressive.glyph)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(DesignTokens.Colors.placeholderFill)
                    }
                    .frame(width: DesignTokens.Metrics.photoThumbnail, height: DesignTokens.Metrics.photoThumbnail)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.inset, style: .continuous))
                    .accessibilityLabel(photo.label)
                }
            }
        }
        .beckonTracksScroll()
    }

    /// "Size M · 28 lb", whatever of it is known.
    private var build: String? {
        let parts = [pet.size.flatMap { $0.isEmpty ? nil : "Size \($0)" }, pet.weightLbs.map { "\(Int($0.rounded())) lb" }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func clean(_ text: String?) -> String? {
        text.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }
}


extension GroomingRequestPetSnapshot {
    /// "4 years old" or "8 months old" from the birthday ("2022-03-14"); nil when it is not known or not a date.
    var beckonAgeLine: String? {
        guard let birthday else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: birthday) else { return nil }
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date, to: Date())
        let years = max(0, parts.year ?? 0)
        if years > 0 { return years == 1 ? "1 year old" : "\(years) years old" }
        let months = max(0, parts.month ?? 0)
        return months == 1 ? "1 month old" : "\(months) months old"
    }
}
