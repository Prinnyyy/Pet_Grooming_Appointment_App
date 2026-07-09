import MapKit
import PhotosUI
import SwiftUI

struct GroomerProfileEditorView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                GroomlySectionHeader(
                    "Profile Details",
                    subtitle: "Update the public details customers see before they book."
                )

                GroomerAvatarEditorSection(store: store)
                GroomerProfileFormSection(store: store)
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, 120)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .background {
            GroomerProfileStatusView(store: store)
        }
        .accessibilityIdentifier("groomer.profile.edit")
    }
}

private struct GroomerAvatarEditorSection: View {
    @Bindable var store: GroomerProfileStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        let hasSavedPhoto = store.profile?.avatarPath != nil
        let photoStatusText = hasSavedPhoto ? "Photo saved to your profile." : "Add a clear face photo."
        let photoActionTitle = hasSavedPhoto ? "Replace Photo" : "Upload Photo"
        let isBusy = store.isBusy

        GroomlyCard {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
                ZStack(alignment: .bottomTrailing) {
                    GroomerAvatarImage(
                        data: store.avatarPhotoData,
                        size: 94,
                        cornerRadius: 28,
                        placeholderSize: 38
                    )

                    if hasSavedPhoto {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.success)
                            .background(Circle().fill(DesignTokens.Colors.surface))
                            .accessibilityLabel("Profile photo saved")
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Profile Photo")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text(photoStatusText)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(
                            photoActionTitle,
                            systemImage: "camera"
                        )
                    }
                    .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer))
                    .disabled(isBusy)
                    .accessibilityIdentifier("groomer.profile.avatar.upload")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await upload(newItem)
            }
        }
    }

    private func upload(_ item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            store.errorMessage = "We could not read that photo."
            return
        }

        let contentType = item.supportedContentTypes
            .lazy
            .compactMap(GroomerAvatarPhotoContentType.init(uniformType:))
            .first ?? .jpeg

        guard let payload = GroomerAvatarImageEncoder.displayablePayload(
            from: data,
            preferredContentType: contentType
        ) else {
            store.errorMessage = "We could not read that photo."
            return
        }

        await store.uploadAvatarPhoto(
            data: payload.data,
            contentType: payload.contentType
        )
    }
}

private struct GroomerProfileFormSection: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GroomlySectionHeader(
                    "Marketplace Profile",
                    subtitle: "Complete these fields before making your profile active."
                ) {
                    if let profile = store.profile {
                        GroomlyStatusChip(
                            profile.isActive ? "Active" : "Hidden",
                            systemImage: profile.isActive ? "checkmark.circle.fill" : "eye.slash",
                            tone: profile.isActive ? .success : .neutral
                        )
                    }
                }

                GroomlyCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomerProfileTextField(
                            title: "Business Name",
                            text: $store.businessName,
                            prompt: "Business Name"
                        )
                        .textContentType(.organizationName)

                        GroomerProfileTextField(
                            title: "Biography",
                            text: $store.bio,
                            prompt: "Biography",
                            axis: .vertical
                        )
                        .lineLimit(3...6)

                        GroomerExperiencePicker(selection: $store.yearsExperience)
                    }
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GroomlySectionHeader(
                    "Address",
                    subtitle: "Use the address customers visit, or your base address for mobile appointments."
                )

                GroomlyCard {
                    GroomerProfileAddressFields(
                        streetAddress: $store.baseStreetAddress,
                        city: $store.baseCity,
                        stateCode: $store.baseStateCode,
                        zipCode: $store.baseZipCode
                    )
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GroomlySectionHeader(
                    "Service Settings",
                    subtitle: "Choose where you work and how far you travel."
                )

                GroomlyCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomerProfileRadiusSlider(radius: $store.serviceRadiusMiles)
                        GroomerProfileLocationModePicker(selection: $store.serviceLocationModes)
                    }
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GroomlySectionHeader(
                    "Profile Visibility",
                    subtitle: "Turn this on when your profile is ready to receive customers."
                )

                GroomlyCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlyToggleRow(
                            title: "Visible to Authenticated Customers",
                            subtitle: "Customers can discover and receive offers from active groomer profiles.",
                            systemImage: "eye",
                            isOn: $store.isActive
                        )

                        if let profile = store.profile {
                            ProfileBadges(profile: profile)
                        }
                    }
                }
            }

            Button {
                Task {
                    await store.saveProfile()
                }
            } label: {
                if store.isSaving {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ProgressView()
                            .tint(DesignTokens.Colors.surface)
                        Text("Saving…")
                    }
                } else {
                    Label("Save Profile", systemImage: "checkmark.circle")
                }
            }
            .buttonStyle(GroomlyPrimaryButtonStyle(accent: .groomer))
            .disabled(store.isBusy)
            .accessibilityIdentifier("groomer.profile.save")

            if store.profile == nil {
                Text("Save your profile once these details are ready.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct GroomerProfileTextField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    let axis: Axis

    init(
        title: String,
        text: Binding<String>,
        prompt: String,
        axis: Axis = .horizontal
    ) {
        self.title = title
        _text = text
        self.prompt = prompt
        self.axis = axis
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            TextField(prompt, text: $text, axis: axis)
                .groomlyFormField()
                .tint(DesignTokens.Colors.groomerAccentDark)
        }
    }
}

private struct GroomerExperiencePicker: View {
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Years Of Experience")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Menu {
                ForEach(0...5, id: \.self) { years in
                    Button(label(for: years)) {
                        selection = years
                    }
                }
            } label: {
                HStack {
                    Text(label(for: selection))
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Spacer(minLength: DesignTokens.Spacing.xs)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .groomlyFormField()
            }
        }
    }

    private func label(for years: Int) -> String {
        years >= 5 ? "5+ Years" : "\(max(0, years)) Year\(years == 1 ? "" : "s")"
    }
}

private struct GroomerProfileRadiusSlider: View {
    @Binding var radius: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Service Radius")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                Spacer()

                Text(radius >= 50 ? "50+ mi" : "\(radius) mi")
                    .font(DesignTokens.Typography.body.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
            }

            Slider(
                value: Binding(
                    get: { Double(radius) },
                    set: { radius = min(max(Int($0.rounded()), 5), 50) }
                ),
                in: 5...50,
                step: 1
            )
            .tint(DesignTokens.Colors.groomerAccent)

            Text("Use 50+ when you cover a wider service area.")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.borderSoft.opacity(0.32))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous))
    }
}

private struct GroomerProfileStatePicker: View {
    let title: String
    @Binding var selection: USStateCode?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Menu {
                ForEach(USStateCode.allCases) { state in
                    Button(state.rawValue) {
                        selection = state
                    }
                }
            } label: {
                HStack {
                    Text(selection?.rawValue ?? "State")
                        .foregroundStyle(
                            selection == nil
                                ? DesignTokens.Colors.textSecondary
                                : DesignTokens.Colors.textPrimary
                        )

                    Spacer(minLength: DesignTokens.Spacing.xs)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .groomlyFormField()
            }
        }
    }
}

private struct GroomerProfileAddressFields: View {
    @Binding var streetAddress: String
    @Binding var city: String
    @Binding var stateCode: USStateCode?
    @Binding var zipCode: String
    @StateObject private var addressSearch = GroomerProfileAddressSearch()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomerProfileTextField(
                title: "Street Address",
                text: $streetAddress,
                prompt: "Street Address"
            )
            .textContentType(.streetAddressLine1)
            .onChange(of: streetAddress) { _, newValue in
                addressSearch.update(
                    street: newValue,
                    city: city,
                    stateCode: stateCode
                )
            }

            if !addressSearch.suggestions.isEmpty {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(addressSearch.suggestions.prefix(4)) { suggestion in
                        Button {
                            applyAddressSuggestion(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(DesignTokens.Typography.caption.weight(.semibold))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                                    .lineLimit(1)

                                Text(suggestion.subtitle)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(DesignTokens.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                        .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
                }
            }

            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                GroomerProfileTextField(
                    title: "City",
                    text: $city,
                    prompt: "City"
                )
                .textContentType(.addressCity)

                GroomerProfileStatePicker(
                    title: "State",
                    selection: $stateCode
                )
                .frame(width: 100)
            }

            GroomerProfileTextField(
                title: "ZIP Code",
                text: $zipCode,
                prompt: "ZIP Code"
            )
            .textContentType(.postalCode)
            .keyboardType(.numbersAndPunctuation)
        }
    }

    private func applyAddressSuggestion(_ suggestion: GroomerProfileAddressSuggestion) {
        Task {
            guard let address = await addressSearch.resolve(suggestion) else { return }
            streetAddress = address.streetAddress
            city = address.city
            stateCode = address.stateCode
            zipCode = address.zipCode
        }
    }
}

private struct GroomerProfileLocationModePicker: View {
    @Binding var selection: Set<GroomingLocationMode>

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Service Location")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            VStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(GroomingLocationMode.allCases) { mode in
                    Button {
                        if selection.contains(mode) {
                            selection.remove(mode)
                        } else {
                            selection.insert(mode)
                        }
                    } label: {
                        let isSelected = selection.contains(mode)
                        HStack(spacing: DesignTokens.Spacing.md) {
                            Text(mode.icon)
                                .font(.title3)
                                .frame(width: 30)

                            Text(mode.groomerTitle)
                                .font(DesignTokens.Typography.body.weight(.semibold))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                            }
                        }
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Colors.surface)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.input,
                                style: .continuous
                            )
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.input,
                                style: .continuous
                            )
                            .stroke(
                                isSelected
                                    ? DesignTokens.Colors.groomerAccent
                                    : DesignTokens.Colors.borderSoft,
                                lineWidth: isSelected ? 2 : 1
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct GroomlyToggleRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    @Binding var isOn: Bool

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        _isOn = isOn
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                .frame(
                    width: DesignTokens.Spacing.xl,
                    height: DesignTokens.Spacing.xl
                )
                .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(DesignTokens.Colors.groomerAccent)
        }
        .padding(DesignTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .fill(DesignTokens.Colors.borderSoft.opacity(0.35))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
