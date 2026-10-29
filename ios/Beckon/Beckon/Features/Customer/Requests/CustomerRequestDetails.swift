// Step 4 of the request wizard, "Details", redesigned from what the groomer needs from it (S-044).
// Notes are what a groomer cannot see in a profile: how the coat is today, what frightens the pet. A blank box does not ask for
// that, so the page names the usual things as chips, and says plainly when the note is required (a custom request) and when the
// limit is near. Photos are shown as the grid a groomer will look at, with the add tile in it.
import PhotosUI
import SwiftUI


enum CustomerRequestPhotoSelectionCopy {
    /// The grid is on the page of this request, so "Photos" is enough; the sentence that told it from the profile photo is gone (S-066).
    static let title = "Photos"
}


// MARK: Notes

/// Sentences a customer taps to add, instead of finding the words alone. Tapping one again takes it out.
private enum CustomerRequestNoteStarter: CaseIterable {
    case matted, dryers, skin, senior, breaks, nips

    var title: String {
        switch self {
        case .matted: "Matted spots"
        case .dryers: "Dryer-shy"
        case .skin: "Sensitive skin"
        case .senior: "Senior pet"
        case .breaks: "Needs breaks"
        case .nips: "Can nip"
        }
    }

    var sentence: String {
        switch self {
        case .matted: "Has matted spots."
        case .dryers: "Gets nervous around dryers."
        case .skin: "Has sensitive skin."
        case .senior: "Is a senior pet and needs gentle handling."
        case .breaks: "Needs short breaks."
        case .nips: "Can nip when scared."
        }
    }
}


struct CustomerRequestNotesSection: View {
    @Bindable var store: CustomerRequestsStore
    let flow: CustomerRequestWizardState
    @Environment(\.dynamicTypeSize) private var typeSize
    var isFocused: FocusState<Bool>.Binding
    let errorText: String?
    let onFocus: () -> Void

    private static let maximumLength = 2000

    private var isCustomRequest: Bool { store.serviceType == .customRequest }
    private var trimmedCount: Int { store.serviceNotes.trimmingCharacters(in: .whitespacesAndNewlines).count }
    private var missing: Int { max(0, CustomerRequestsStore.minimumCustomRequestNotesLength - trimmedCount) }
    private var nearsLimit: Bool { store.serviceNotes.count >= Self.maximumLength - 200 }

    var body: some View {
        DesignSection(title: "Notes", systemImage: "text.bubble", spacing: DesignTokens.Spacing.md) {
            requirement

            TextField("Anything the groomer should know", text: $store.serviceNotes, axis: .vertical)
                .lineLimit(5...8)
                .focused(isFocused)
                .beckonFormField(isInvalid: flow.invalidFields.contains(.notes))
                .accessibilityIdentifier("customer.requests.wizard.notes")
                .onTapGesture {
                    flow.clearInvalidField(.notes)
                    isFocused.wrappedValue = true
                }
                .onChange(of: store.serviceNotes) { _, _ in flow.clearInvalidField(.notes) }
                .onChange(of: isFocused.wrappedValue) { _, focused in if focused { onFocus() } }

            // The line under the box exists only when it has something to say: how much a custom request still needs, or that the
            // limit is close. "12 / 2,000" under an empty box was a number nobody was asking for.
            if isCustomRequest || nearsLimit {
                let counterLayout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
                    : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))
                counterLayout {
                    if isCustomRequest {
                        Label(missing == 0 ? "Enough to go on" : "\(missing) more characters needed",
                            systemImage: missing == 0 ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .font(DesignTokens.Typography.Expressive.chip)
                            .foregroundStyle(missing == 0 ? DesignTokens.Colors.statusSuccessText : DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    if nearsLimit {
                        Text("\(store.serviceNotes.count) / \(Self.maximumLength)")
                            .font(DesignTokens.Typography.Expressive.chip)
                            .foregroundStyle(store.serviceNotes.count > Self.maximumLength ? DesignTokens.Colors.statusErrorText : DesignTokens.Colors.textTertiary)
                            .monospacedDigit()
                    }
                }
            }

            if let errorText { BeckonInlineError(errorText) }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                // One chip to a line at accessibility sizes: a word never breaks to fit two columns.
                LazyVGrid(columns: typeSize.isAccessibilitySize
                    ? [GridItem(.flexible(), alignment: .leading)]
                    : [GridItem(.adaptive(minimum: 150), spacing: DesignTokens.Spacing.sm, alignment: .leading)],
                    alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    ForEach(CustomerRequestNoteStarter.allCases, id: \.self) { starter in
                        let isOn = store.serviceNotes.contains(starter.sentence)
                        DesignChoiceChip(title: starter.title, systemImage: isOn ? "checkmark" : "plus", isSelected: isOn) {
                            toggle(starter.sentence)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var requirement: some View {
        // Only a custom request needs saying: every other request has its notes optional, and the page does not announce that.
        if isCustomRequest {
            Label("Required: tell the groomer what you need.", systemImage: "pencil.and.list.clipboard")
                .font(DesignTokens.Typography.Expressive.supporting)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toggle(_ sentence: String) {
        flow.clearInvalidField(.notes)
        var notes = store.serviceNotes
        if let range = notes.range(of: sentence) {
            notes.removeSubrange(range)
            notes = notes.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let separator = notes.isEmpty || notes.hasSuffix(" ") || notes.hasSuffix("\n") ? "" : " "
            let combined = notes + separator + sentence
            guard combined.count <= Self.maximumLength else { return }
            notes = combined
        }
        store.serviceNotes = notes
    }
}


// MARK: Photos

/// The photos of this request as the grid a groomer will see, with the add tile as its last cell.
struct CustomerRequestPhotosSection: View {
    let photos: [PendingGroomingRequestPhoto]
    @Binding var selection: [PhotosPickerItem]
    let onRemove: (UUID) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.sm), count: 3)

    var body: some View {
        let addSpacing = DesignTokens.Spacing.xs
        let addIconFont = DesignTokens.Typography.Expressive.glyphLarge
        let addLabelFont = DesignTokens.Typography.Expressive.chip
        let addInk = DesignTokens.Colors.customerDeep
        return DesignSection(
            title: CustomerRequestPhotoSelectionCopy.title,
            systemImage: "photo.on.rectangle",
            count: photos.count,
            spacing: DesignTokens.Spacing.md
        ) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ForEach(photos) { photo in
                    CustomerRequestPhotoCell(photo: photo) { onRemove(photo.id) }
                }
                PhotosPicker(selection: $selection, matching: .images) {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            VStack(spacing: addSpacing) {
                                Image(systemName: "plus")
                                    .font(addIconFont)
                                Text("Add photos")
                                    .font(addLabelFont)
                            }
                            .foregroundStyle(addInk)
                        }
                }
                .buttonStyle(BeckonLedgePressStyle(.dashed))
                .accessibilityLabel("Add request photos")
                .accessibilityIdentifier("customer.requests.wizard.add-photos")
            }
            .accessibilityIdentifier("customer.requests.wizard.photo-preview")
        }
    }
}


private struct CustomerRequestPhotoCell: View {
    let photo: PendingGroomingRequestPhoto
    let onRemove: () -> Void

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                BeckonModuleImage(data: photo.data) {
                    Image(systemName: "photo")
                        .font(DesignTokens.Typography.Expressive.glyphLarge)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DesignTokens.Colors.placeholderFill)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.border, lineWidth: DesignTokens.Ledge.edgeWidth)
            }
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.Expressive.micro)
                        .foregroundStyle(DesignTokens.Colors.statusErrorText)
                        .frame(width: 28, height: 28)
                        .background(DesignTokens.Colors.surface, in: Circle())
                        .overlay { Circle().strokeBorder(DesignTokens.Colors.statusErrorBorder, lineWidth: 1) }
                        .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: DesignTokens.Metrics.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .accessibilityLabel("Remove request photo")
                .accessibilityIdentifier("customer.requests.wizard.remove-photo.\(photo.id.uuidString)")
            }
            .accessibilityElement(children: .contain)
    }
}
