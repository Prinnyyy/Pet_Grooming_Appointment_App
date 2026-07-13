import PhotosUI
import SwiftUI
import UIKit

nonisolated enum CustomerPetNameInput {
    static let maximumLength = 20

    static func acceptedValue(current: String, proposed: String) -> String {
        proposed.count <= maximumLength ? proposed : current
    }
}

nonisolated enum CustomerPetFormFocusTarget: String, CaseIterable, Hashable {
    case name = "customer.pets.form.name.container"
    case medicalNotes = "customer.pets.form.medical-notes.container"
    case groomingNotes = "customer.pets.form.grooming-notes.container"
}

struct CustomerPetFormView: View {
    @Bindable var store: CustomerPetsStore
    @FocusState private var focusedField: CustomerPetFormFocusTarget?

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        BeckonAnnotatedModule(
                            "Pet Profile",
                            subtitle: "Pet identity, avatar, breed, and coat details."
                        ) {
                            VStack(spacing: DesignTokens.Spacing.md) {
                                CustomerPetFormPhotoModule(store: store)

                                BeckonCard {
                                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                                        CustomerPetFormLabeledTextField(
                                            title: "Name",
                                            placeholder: "Pet name",
                                            text: $store.formName,
                                            allowsMultiline: false,
                                            maximumLength: CustomerPetNameInput.maximumLength,
                                            focusTarget: .name,
                                            focusedField: $focusedField
                                        )

                                        CustomerPetFormChoiceRow(
                                            title: "Species",
                                            subtitle: store.formSpecies.title
                                        ) {
                                            ForEach(CustomerPetSpecies.allCases) { species in
                                                CustomerPetFormChip(
                                                    title: species.title,
                                                    isSelected: store.formSpecies == species
                                                ) {
                                                    store.updateFormSpecies(species)
                                                }
                                            }
                                        }

                                        CustomerPetFormChoiceRow(
                                            title: "Breed",
                                            subtitle: store.formBreed.title
                                        ) {
                                            ForEach(CustomerPetBreed.options(for: store.formSpecies)) { breed in
                                                CustomerPetFormChip(
                                                    title: breed.title,
                                                    isSelected: store.formBreed == breed
                                                ) {
                                                    store.updateFormBreed(breed)
                                                }
                                            }
                                        }

                                        CustomerPetFormChoiceRow(
                                            title: "Coat Type",
                                            subtitle: store.formCoatType.title
                                        ) {
                                            ForEach(CustomerPetCoatType.displayOptions) { coatType in
                                                CustomerPetFormChip(
                                                    title: coatType.title,
                                                    isSelected: store.formCoatType == coatType
                                                ) {
                                                    store.formCoatType = coatType
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        BeckonAnnotatedModule(
                            "Details",
                            subtitle: "Size, birthday, temperament, and care notes."
                        ) {
                            BeckonCard {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                                    CustomerPetWeightControl(
                                        weight: $store.formWeightLbs,
                                        weightText: weightText,
                                        sizeTitle: CustomerPetSizeCode
                                            .code(forWeightLbs: store.formWeightLbs)
                                            .title
                                    )

                                CustomerPetBirthdayControl(
                                    isKnown: birthdayKnownBinding,
                                    date: birthdayBinding
                                )

                                CustomerPetFormChoiceRow(
                                    title: "Temperament",
                                    subtitle: store.formTemperament.title
                                ) {
                                    ForEach(CustomerPetTemperament.displayOptions) { temperament in
                                        CustomerPetFormChip(
                                            title: temperament.title,
                                            isSelected: store.formTemperament == temperament
                                        ) {
                                            store.formTemperament = temperament
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                    CustomerPetFormLabeledTextField(
                                        title: "Medical Notes",
                                        placeholder: "Allergies, medication, injuries",
                                        text: $store.formMedicalNotes,
                                        focusTarget: .medicalNotes,
                                        focusedField: $focusedField
                                    )

                                    CustomerPetFormLabeledTextField(
                                        title: "Grooming Notes",
                                        placeholder: "Anxiety, coat needs, handling preferences",
                                        text: $store.formGroomingNotes,
                                        focusTarget: .groomingNotes,
                                        focusedField: $focusedField
                                    )
                                }
                                }
                            }
                        }

                        if let errorMessage = store.errorMessage {
                            BeckonErrorBanner(
                                title: "Check Pet Details",
                                message: errorMessage
                            )
                            .accessibilityIdentifier("customer.pets.form-error")
                        }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                        .padding(.top, DesignTokens.Spacing.lg)
                        .padding(.bottom, DesignTokens.Spacing.xl * 5)
                    }
                    .beckonKeyboardAvoidance(
                        focusedTarget: focusedField?.rawValue,
                        using: scrollProxy
                    )
                }
            }
            .tint(DesignTokens.Colors.customerPrimaryDark)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .beckonStationaryPageAction {
                CustomerPetFormBottomBar(store: store)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.cancelForm()
                    }
                    .disabled(store.isSaving)
                }
                ToolbarItem(placement: .principal) {
                    Text(store.formTitle)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }
            }
        }
        .interactiveDismissDisabled(store.isSaving)
    }

    private var birthdayKnownBinding: Binding<Bool> {
        Binding(
            get: { store.formBirthdayDate != nil },
            set: { isKnown in
                store.formBirthdayDate = isKnown
                    ? store.formBirthdayDate ?? Date()
                    : nil
            }
        )
    }

    private var birthdayBinding: Binding<Date> {
        Binding(
            get: { store.formBirthdayDate ?? Date() },
            set: { store.formBirthdayDate = $0 }
        )
    }

    private var weightText: String {
        if store.formWeightLbs < 10 {
            return "<10 lbs"
        }
        if store.formWeightLbs > 100 {
            return ">100 lbs"
        }
        return "\(Int(store.formWeightLbs.rounded())) lbs"
    }

}

private struct CustomerPetFormPhotoModule: View {
    @Bindable var store: CustomerPetsStore

    var body: some View {
        BeckonPhotoEditorCard(
            title: "Pet Photo",
            statusText: store.formAvatarPhotoData == nil
                ? "Add a photo for this pet."
                : "Photo saved to this pet profile.",
            showsSavedIndicator: false,
            savedAccessibilityLabel: "Pet photo saved"
        ) {
            CustomerPetFormAvatarPreview(data: store.formAvatarPhotoData)
                .accessibilityHidden(true)
        } action: {
            CustomerPetFormPhotoPicker(store: store)
        }
    }
}

private enum CustomerPetFormTypography {
    static let sectionTitle = DesignTokens.Typography.headline
    static let fieldLabel = DesignTokens.Typography.caption.weight(.bold)
    static let fieldValue = DesignTokens.Typography.body.weight(.semibold)
    static let supporting = DesignTokens.Typography.caption
}

private struct CustomerPetFormAvatarPreview: View {
    let data: Data?

    var body: some View {
        BeckonModuleImage(data: data) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.Colors.customerPrimary.opacity(0.16))
        }
        .frame(width: 96, height: 96)
        .background(DesignTokens.Colors.customerPrimary.opacity(0.12))
        .clipShape(DesignTokens.Shapes.circular)
        .overlay {
            Circle()
                .stroke(DesignTokens.Colors.customerPrimary.opacity(0.26), lineWidth: 2)
        }
        .accessibilityHidden(true)
    }
}

private struct CustomerPetFormChoiceRow<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(CustomerPetFormTypography.fieldLabel)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                Spacer(minLength: DesignTokens.Spacing.md)

                Text(subtitle)
                    .font(CustomerPetFormTypography.supporting)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        content
                    }
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
                .onAppear {
                    scrollToSelection(using: proxy)
                }
                .onChange(of: subtitle) { _, _ in
                    scrollToSelection(using: proxy)
                }
            }
        }
    }

    private func scrollToSelection(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo(subtitle, anchor: .leading)
        }
    }
}

private struct CustomerPetFormChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CustomerPetFormTypography.fieldValue)
                .foregroundStyle(
                    isSelected
                        ? DesignTokens.Colors.customerPrimaryDark
                        : DesignTokens.Colors.textSecondary
                )
                .lineLimit(1)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .frame(height: 44)
                .background {
                    Capsule()
                        .fill(
                            isSelected
                                ? DesignTokens.Colors.customerPrimary.opacity(0.18)
                                : DesignTokens.Colors.surface
                        )
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isSelected
                                ? DesignTokens.Colors.customerPrimary
                                : DesignTokens.Colors.border,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                }
        }
        .buttonStyle(.plain)
        .id(title)
    }
}

private struct CustomerPetFormLabeledTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var allowsMultiline = true
    var isInvalid = false
    var maximumLength: Int?
    let focusTarget: CustomerPetFormFocusTarget
    @FocusState.Binding var focusedField: CustomerPetFormFocusTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(CustomerPetFormTypography.fieldLabel)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            if let maximumLength, !allowsMultiline {
                BeckonLimitedTextField(
                    placeholder: placeholder,
                    text: $text,
                    maximumLength: maximumLength,
                    isInvalid: isInvalid,
                    onEditingBegan: {
                        focusedField = focusTarget
                    }
                )
            } else {
                TextField(
                    placeholder,
                    text: $text,
                    axis: allowsMultiline ? .vertical : .horizontal
                )
                .lineLimit(allowsMultiline ? 2...5 : 1...1)
                .focused($focusedField, equals: focusTarget)
                .beckonFormField(isInvalid: isInvalid)
            }
        }
        .beckonKeyboardFocusTarget(focusTarget.rawValue)
    }
}

private struct CustomerPetWeightControl: View {
    @Binding var weight: Double
    let weightText: String
    let sizeTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Weight")
                        .font(CustomerPetFormTypography.fieldLabel)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    Text("Size is calculated automatically")
                        .font(CustomerPetFormTypography.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }

                Spacer(minLength: DesignTokens.Spacing.md)

                VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                    Text(weightText)
                        .font(CustomerPetFormTypography.fieldValue)
                        .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)

                    Text(sizeTitle)
                        .font(CustomerPetFormTypography.fieldLabel)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }

            Slider(value: $weight, in: 5...101, step: 1)
                .tint(DesignTokens.Colors.customerPrimary)
        }
    }
}

private struct CustomerPetBirthdayControl: View {
    @Binding var isKnown: Bool
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Toggle("Birthday Known", isOn: $isKnown)
                .font(CustomerPetFormTypography.fieldLabel)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .tint(DesignTokens.Colors.customerPrimary)

            if isKnown {
                DatePicker(
                    "",
                    selection: $date,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .font(CustomerPetFormTypography.fieldValue)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct CustomerPetFormBottomBar: View {
    @Bindable var store: CustomerPetsStore

    var body: some View {
        VStack(spacing: 0) {
            Button {
                Task {
                    await store.savePet()
                }
            } label: {
                Text(store.isSaving ? "Saving..." : "Save Pet")
            }
            .buttonStyle(BeckonPrimaryButtonStyle(accent: .customer))
            .disabled(store.isSaving)
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(
                LinearGradient(
                    colors: [
                        DesignTokens.Colors.background.opacity(0.2),
                        DesignTokens.Colors.background,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
    }
}

private struct CustomerPetFormPhotoPicker: View {
    @Bindable var store: CustomerPetsStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        let avatarActionTitle = store.formAvatarPhotoData == nil ? "Upload Photo" : "Replace Photo"

        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images
        ) {
            Label(
                avatarActionTitle,
                systemImage: "camera"
            )
                .lineLimit(1)
        }
        .buttonStyle(BeckonSecondaryButtonStyle(accent: .customer))
        .disabled(store.isSaving)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await addPendingPhoto(newItem)
            }
        }
    }

    private func addPendingPhoto(_ item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            store.errorMessage = "We could not read that photo."
            return
        }

        let contentType = item.supportedContentTypes
            .lazy
            .compactMap(CustomerPetPhotoContentType.init(uniformType:))
            .first ?? .jpeg

        store.addPendingFormPhoto(
            data: data,
            contentType: contentType
        )
    }
}

struct CustomerPetsStatusView: View {
    let store: CustomerPetsStore

    var body: some View {
        BeckonGlobalFeedbackForwarder(
            noticeMessage: store.noticeMessage,
            clearNotice: { message in
                guard store.noticeMessage == message else { return }
                store.noticeMessage = nil
            },
            error: errorPrompt,
            progress: progressPrompt
        )
    }

    private var errorPrompt: BeckonGlobalFeedbackError? {
        guard let errorMessage = store.errorMessage,
              !store.isShowingPetForm else { return nil }
        return BeckonGlobalFeedbackError(
            scope: .page("customer.pets"),
            sourceKey: "customer.pets.error",
            title: "We Could Not Update Your Pets",
            message: errorMessage
        )
    }

    private var progressPrompt: BeckonGlobalFeedbackProgress? {
        guard store.isSaving || store.isUploading else { return nil }
        return BeckonGlobalFeedbackProgress(
            scope: .operation("customer.pets.save"),
            sourceKey: "customer.pets.save-progress",
            title: store.isUploading ? "Uploading…" : "Saving…",
            tone: .customer
        )
    }
}
