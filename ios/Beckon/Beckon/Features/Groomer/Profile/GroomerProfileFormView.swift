import MapKit
import PhotosUI
import SwiftUI

struct GroomerProfileEditorView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        let presentation = GroomerProfileEditorPresentation(
            isSaving: store.isSaving,
            isBusy: store.isBusy
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                GroomerAvatarEditorSection(store: store)
                GroomerProfileFormSection(store: store)
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .accessibilityIdentifier("groomer.profile.edit")
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GroomerProfileSaveActionBar(
                presentation: presentation,
                save: {
                    await store.saveProfile()
                }
            )
        }
        .background {
            GroomerProfileStatusView(store: store)
        }
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

        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            ZStack(alignment: .bottomTrailing) {
                BeckonProfileAvatar(
                    data: store.avatarPhotoData,
                    tone: .groomer,
                    size: 88,
                    cornerRadius: 44,
                    placeholderSize: 34
                )

                if hasSavedPhoto {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.success)
                        .background(Circle().fill(DesignTokens.Colors.surface))
                        .accessibilityLabel("Profile photo saved")
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Profile photo")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text(photoStatusText)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(
                        photoActionTitle,
                        systemImage: "camera"
                    )
                }
                .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer, isFullWidth: false))
                .disabled(isBusy)
                .accessibilityIdentifier("groomer.profile.avatar.upload")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            GroomerWorkspaceSection(title: "Business details") {
                GroomerGroupedSurface {
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
                    .padding(DesignTokens.Spacing.lg)
                }
            }

            GroomerWorkspaceSection(title: "Service area") {
                GroomerGroupedSurface {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        BeckonAddressEditor(state: store.addressEditorState)

                        GroomerWorkspaceDivider()

                        GroomerProfileRadiusSlider(radius: $store.serviceRadiusMiles)
                        GroomerProfileLocationModePicker(selection: $store.serviceLocationModes)
                    }
                    .padding(DesignTokens.Spacing.lg)
                }
            }

            GroomerWorkspaceSection(title: "Visibility") {
                GroomerGroupedSurface {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        BeckonToggleRow(
                            title: "Visible to Authenticated Customers",
                            subtitle: "Customers can discover and receive offers from active groomer profiles.",
                            systemImage: "eye",
                            isOn: $store.isActive
                        )

                        if let profile = store.profile {
                            ProfileBadges(profile: profile)
                        }
                    }
                    .padding(DesignTokens.Spacing.lg)
                }
            }

            if store.profile == nil {
                Text("Save your profile once these details are ready.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct GroomerProfileSaveActionBar: View {
    let presentation: GroomerProfileEditorPresentation
    let save: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(DesignTokens.Colors.divider)

            Button {
                Task {
                    await save()
                }
            } label: {
                if presentation.actionTitle == "Saving..." {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ProgressView()
                            .tint(DesignTokens.Colors.surface)
                        Text(presentation.actionTitle)
                    }
                } else {
                    Label(presentation.actionTitle, systemImage: "checkmark.circle")
                }
            }
            .buttonStyle(BeckonPrimaryButtonStyle(accent: .groomer))
            .disabled(presentation.isActionDisabled)
            .accessibilityIdentifier("groomer.profile.save")
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Colors.background)
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
                .beckonFormField()
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
                .beckonFormField()
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
                .beckonFormField()
            }
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

struct BeckonToggleRow: View {
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
