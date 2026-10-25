import PhotosUI

import SwiftUI

import UIKit

nonisolated enum CustomerPetNameInput {
    static let maximumLength = CustomerPetFormConstraints.nameMaximumLength

    static func acceptedValue(current: String, proposed: String) -> String {
        proposed.count <= maximumLength ? proposed : current
    }
}

nonisolated enum CustomerPetFormFocusTarget: String, CaseIterable, Hashable {
    case name = "customer.pets.form.name.container"
    case medicalNotes = "customer.pets.form.medical-notes.container"
    case groomingNotes = "customer.pets.form.grooming-notes.container"
}

// Pet editor: a profile hero that previews the pet, ledge cards per group, one mint save button.
// The inputs (fields, chips, sliders, pickers) keep their behavior and stay calm; only chrome and grouping are lively.
struct CustomerPetFormView: View {
    @Bindable var store: CustomerPetsStore
    @FocusState private var focusedField: CustomerPetFormFocusTarget?
    @State private var confirmsReload = false

    var body: some View {
        NavigationStack {
            ZStack {
                BeckonExpressiveBackdrop()

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        BeckonCascade(spacing: DesignTokens.Layout.sectionSpacing) {
                            CustomerPetFormHero(store: store)
                                .disabled(store.formIsFrozen)

                            section("About", systemImage: "pawprint.fill") {
                                CustomerPetFormLabeledTextField(
                                    title: "Name",
                                    placeholder: "Pet name",
                                    text: $store.formName,
                                    allowsMultiline: false,
                                    maximumLength: CustomerPetNameInput.maximumLength,
                                    focusTarget: .name,
                                    focusedField: $focusedField
                                )

                                CustomerPetFormChoiceRow(title: "Species", subtitle: store.formSpecies.title) {
                                    ForEach(CustomerPetSpecies.allCases) { species in
                                        CustomerPetFormChip(title: species.title, isSelected: store.formSpecies == species) {
                                            store.updateFormSpecies(species)
                                        }
                                    }
                                }

                                CustomerPetFormChoiceRow(title: "Breed", subtitle: store.formBreed.title) {
                                    ForEach(CustomerPetBreed.options(for: store.formSpecies)) { breed in
                                        CustomerPetFormChip(title: breed.title, isSelected: store.formBreed == breed) {
                                            store.updateFormBreed(breed)
                                        }
                                    }
                                }

                                CustomerPetFormChoiceRow(title: "Coat type", subtitle: store.formCoatType.title) {
                                    ForEach(CustomerPetCoatType.displayOptions) { coatType in
                                        CustomerPetFormChip(title: coatType.title, isSelected: store.formCoatType == coatType) {
                                            store.formCoatType = coatType
                                        }
                                    }
                                }
                            }

                            section("Size and age", systemImage: "ruler.fill") {
                                Toggle("Weight known", isOn: $store.formWeightIsKnown)
                                    .font(CustomerPetFormTypography.fieldLabel)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .tint(DesignTokens.Colors.customerDeep)
                                    .accessibilityIdentifier("customer.pets.weight-known")
                                if store.formWeightIsKnown {
                                    CustomerPetWeightControl(
                                        weight: $store.formWeightLbs,
                                        weightText: weightText,
                                        sizeTitle: CustomerPetSizeCode.code(forWeightLbs: store.formWeightLbs).title
                                    )
                                }

                                CustomerPetBirthdayControl(isKnown: birthdayKnownBinding, date: birthdayBinding)
                            }

                            section("Care notes", systemImage: "heart.text.square.fill") {
                                CustomerPetFormChoiceRow(title: "Temperament", subtitle: store.formTemperament.title) {
                                    ForEach(CustomerPetTemperament.displayOptions) { temperament in
                                        CustomerPetFormChip(title: temperament.title, isSelected: store.formTemperament == temperament) {
                                            store.formTemperament = temperament
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                    Text("Coat matting")
                                        .font(CustomerPetFormTypography.fieldLabel)
                                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    Picker("Coat matting", selection: $store.formMattingConfirmed) {
                                        Text("Not sure").tag(Bool?.none)
                                        Text("No").tag(Bool?.some(false))
                                        Text("Yes").tag(Bool?.some(true))
                                    }
                                    .pickerStyle(.segmented)
                                    .accessibilityIdentifier("customer.pets.matting")
                                }

                                CustomerPetFormLabeledTextField(
                                    title: "Medical notes",
                                    placeholder: "Allergies, medication, injuries",
                                    text: $store.formMedicalNotes,
                                    focusTarget: .medicalNotes,
                                    focusedField: $focusedField
                                )

                                CustomerPetFormLabeledTextField(
                                    title: "Grooming notes",
                                    placeholder: "Anxiety, coat needs, handling preferences",
                                    text: $store.formGroomingNotes,
                                    focusTarget: .groomingNotes,
                                    focusedField: $focusedField
                                )
                            }

                            if let errorMessage = store.errorMessage {
                                BeckonErrorBanner(title: "Check pet details", message: errorMessage)
                                    .accessibilityIdentifier("customer.pets.form-error")
                            }
                            if store.editNeedsReconciliation {
                                Button { confirmsReload = true } label: {
                                    DesignQuietAction(title: "Reload saved pet", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(BeckonGuardedPlainButtonStyle())
                                .disabled(store.isSaving)
                                .accessibilityIdentifier("customer.pets.reload-saved")
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                        .padding(.top, DesignTokens.Spacing.lg)
                        .padding(.bottom, DesignTokens.Layout.pageBottomInset)
                    }
                        .beckonTracksScroll()
                    .scrollContentBackground(.hidden)
                    .beckonKeyboardAvoidance(
                        focusedTarget: focusedField?.rawValue,
                        using: scrollProxy,
                        additionallyPreventsPresentationDismissal: store.isSaving
                    )
                }
            }
            .beckonStationaryPageAction { saveBar }
            .beckonEntranceRhythm(.step)
            .tint(DesignTokens.Colors.customerDeep)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .designAlertDialog(isPresented: $confirmsReload) {
                .destructive(title: "Replace your edits with the saved pet?",
                    message: "What you changed on this form will be lost.", systemImage: "arrow.counterclockwise",
                    keepTitle: "Keep Editing", confirmTitle: "Reload Saved Pet", confirmSystemImage: "arrow.counterclockwise") {
                    Task { await store.reloadEditedPet() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.cancelForm() }
                        .disabled(store.isSaving)
                }
                ToolbarItem(placement: .principal) {
                    Text(store.formTitle)
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, systemImage: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        DesignSection(title: title, systemImage: systemImage, spacing: DesignTokens.Spacing.lg) { content() }
            .disabled(store.formIsFrozen)
    }

    private var saveBar: some View {
        Button { Task { await store.savePet() } } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if store.isSaving { ProgressView().tint(DesignTokens.Colors.customerInk) }
                Text(store.isSaving ? "Saving..." : store.formActionTitle)
                    .font(DesignTokens.Typography.Expressive.headline)
                if !store.isSaving {
                    Image(systemName: "checkmark").font(DesignTokens.Typography.Expressive.glyph)
                }
            }
            .foregroundStyle(DesignTokens.Colors.customerInk)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.pill))
        .disabled(!store.canSaveForm)
        .beckonBump(trigger: 0)
        .accessibilityIdentifier("customer.pets.form-save")
        .padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
        .padding(.vertical, DesignTokens.Layout.actionAreaInset)
        .background(DesignTokens.Colors.appBackground.ignoresSafeArea())
        .overlay(alignment: .top) { DesignTokens.Colors.borderSoft.frame(height: DesignTokens.Ledge.edgeWidth / 2) }
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
        "\(store.formWeightLbs.formatted(.number.precision(.fractionLength(0...2)))) lbs"
    }
}

/// The pet's profile ticket: avatar, live name and breed, and the photo action. Mint wash so the paw avatar sits on a fill.
private struct CustomerPetFormHero: View {
    @Bindable var store: CustomerPetsStore
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.lg))
                : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.lg))) {
                CustomerPetFormAvatarPreview(data: store.formAvatarPhotoData)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(store.formName.trimmingCharacters(in: .whitespaces).isEmpty ? "Your pup" : store.formName)
                        .font(DesignTokens.Typography.Expressive.title)
                        .foregroundStyle(DesignTokens.Colors.customerInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(store.formSpecies.title) · \(store.formBreed.title)")
                        .font(DesignTokens.Typography.Expressive.supporting)
                        .foregroundStyle(DesignTokens.Colors.customerInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            CustomerPetFormPhotoPicker(store: store)
        }
        .designBanner()
        .accessibilityElement(children: .contain)
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
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.Colors.customerTint)
        }
        .frame(width: 96, height: 96)
        .background(DesignTokens.Colors.surface)
        .clipShape(DesignTokens.Shapes.circular)
        .overlay {
            Circle()
                .strokeBorder(DesignTokens.Colors.surface, lineWidth: 4)
        }
        .background(Circle().fill(DesignTokens.Colors.customerDeep).offset(y: DesignTokens.Ledge.control))
        .padding(.bottom, DesignTokens.Ledge.control)
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
                        ? DesignTokens.Colors.customerInk
                        : DesignTokens.Colors.textSecondary
                )
                .lineLimit(1)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .frame(height: 44)
                .background {
                    Capsule()
                        .fill(
                            isSelected
                                ? DesignTokens.Colors.customerFill
                                : DesignTokens.Colors.surface
                        )
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isSelected
                                ? DesignTokens.Colors.customerFillPressed
                                : DesignTokens.Colors.border,
                            lineWidth: isSelected ? 2 : 1
                        )
                }
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
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
                        .foregroundStyle(DesignTokens.Colors.customerDeep)

                    Text(sizeTitle)
                        .font(CustomerPetFormTypography.fieldLabel)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }

            Slider(value: Binding(get: { min(101, max(0.1, weight)) }, set: { weight = $0 }), in: 0.1...101, step: 0.1)
                .tint(DesignTokens.Colors.customerDeep)
            HStack {
                TextField("Weight in pounds", value: $weight, format: .number)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("customer.pets.weight-input")
                Stepper("Weight", value: $weight, step: 0.1)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("customer.pets.weight-stepper")
            }
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
                .tint(DesignTokens.Colors.customerDeep)

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

private struct CustomerPetFormPhotoPicker: View {
    @Bindable var store: CustomerPetsStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        let avatarActionTitle = store.formAvatarPhotoData == nil ? "Upload Photo" : "Replace Photo"

        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images
        ) {
            Label(avatarActionTitle, systemImage: "camera.fill")
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
        }
        .buttonStyle(BeckonLedgePressStyle(.card))
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
            title: "We could not update your pets",
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
