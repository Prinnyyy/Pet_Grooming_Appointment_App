// Profile settings, in the customer prototype's language (design). Same job as GroomerProfileEditorView in
// Features/Groomer/Profile/GroomerProfileFormView.swift: the profile photo, the business (name, biography, years), the service area
// (address, radius, where the work happens) and whether customers can find the profile. The store, the address editor, the focus
// targets and the ids are the real ones. What is new is the surface (ledge sections, one pinned Save) and the order of nothing.
import PhotosUI
import SwiftUI
import UIKit


struct GroomerProfileEditorView: View {
    @Bindable var store: GroomerProfileStore
    @State private var addressFocusTarget: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @FocusState private var focusedTarget: String?

    var body: some View {
        let presentation = GroomerProfileEditorPresentation(isSaving: store.isSaving, isBusy: store.isBusy)

        ScrollViewReader { proxy in
            DesignPage {
                photo
                details
                area
                visibility
                if store.profile == nil {
                    DesignInfoLine(systemImage: "info.circle", text: "Save your profile once these details are ready.")
                }
                GroomerBarClearance()
            }
            .beckonKeyboardAvoidance(focusedTarget: focusedTarget ?? addressFocusTarget, using: proxy,
                additionallyPreventsPresentationDismissal: store.isBusy)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Profile settings")
        .navigationBarTitleDisplayMode(.inline)
        .beckonHidesTabBar()
        .onChange(of: focusedTarget) { _, target in
            if target != nil { addressFocusTarget = nil }
        }
        .background { GroomerProfileStatusView(store: store) }
        .beckonStationaryPageAction {
            GroomerSaveBar(title: "Save profile", isSaving: store.isSaving, isDisabled: presentation.isActionDisabled,
                identifier: "groomer.profile.save") {
                Task { await store.saveProfile() }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.profile.edit")
    }

    // MARK: Photo

    private var photo: some View {
        let hasSavedPhoto = store.profile?.avatarPath != nil || store.avatarPhotoData != nil
        return BeckonPhotoEditorCard(title: "Profile photo",
            statusText: hasSavedPhoto ? "Photo saved to your profile." : "Add a clear face photo.",
            showsSavedIndicator: hasSavedPhoto, savedAccessibilityLabel: "Profile photo saved") {
            BeckonProfileAvatar(data: store.avatarPhotoData, tone: .groomer, size: DesignTokens.Metrics.profilePhoto,
                cornerRadius: DesignTokens.Metrics.profilePhoto / 2,
                placeholderSize: DesignTokens.Metrics.profilePhoto * 0.4)
                .accessibilityHidden(true)
        } action: {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label(hasSavedPhoto ? "Replace Photo" : "Upload Photo", systemImage: "camera.fill")
            }
            .buttonStyle(BeckonSecondaryButtonStyle(accent: .neutral))
            .disabled(store.isBusy)
            .accessibilityIdentifier("groomer.profile.avatar.upload")
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
    }

    private func upload(_ item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            store.errorMessage = "We could not read that photo."
            store.actionErrorMessage = store.errorMessage
            return
        }
        let contentType = item.supportedContentTypes.lazy.compactMap(GroomerAvatarPhotoContentType.init(uniformType:)).first ?? .jpeg
        guard let payload = GroomerAvatarImageEncoder.displayablePayload(from: data, preferredContentType: contentType) else {
            store.errorMessage = "We could not read that photo."
            store.actionErrorMessage = store.errorMessage
            return
        }
        await store.uploadAvatarPhoto(data: payload.data, contentType: payload.contentType)
    }

    // MARK: Sections

    private var details: some View {
        DesignSection(title: "Business details", systemImage: "briefcase.fill", spacing: DesignTokens.Spacing.lg) {
            GroomerTextField(title: "Business name", text: $store.businessName, prompt: "Business name",
                focusTarget: GroomerProfileFocusTarget.businessName.rawValue, focusedTarget: $focusedTarget)
                .textContentType(.organizationName)
            GroomerTextField(title: "Biography", text: $store.bio, prompt: "Biography", axis: .vertical,
                focusTarget: GroomerProfileFocusTarget.biography.rawValue, focusedTarget: $focusedTarget)
                .lineLimit(3...6)
            GroomerCaptioned(title: "Years of experience") {
                Menu {
                    ForEach(0...5, id: \.self) { years in
                        Button(Self.yearsTitle(years)) { store.yearsExperience = years }
                    }
                } label: {
                    GroomerMenuLabel(text: Self.yearsTitle(store.yearsExperience))
                }
                .accessibilityIdentifier("groomer.profile.years")
            }
        }
    }

    private static func yearsTitle(_ years: Int) -> String {
        years >= 5 ? "5+ Years" : "\(max(0, years)) Year\(years == 1 ? "" : "s")"
    }

    private var area: some View {
        DesignSection(title: "Service area", systemImage: "mappin.and.ellipse", spacing: DesignTokens.Spacing.lg) {
            BeckonAddressEditor(state: store.addressEditorState, onFieldFocused: { target in
                focusedTarget = nil
                addressFocusTarget = target
            })

            GroomerCaptioned(title: "Service radius") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(store.serviceRadiusMiles >= 50 ? "50+ mi" : "\(store.serviceRadiusMiles) mi")
                        .font(DesignTokens.Typography.Expressive.title)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                    Slider(value: Binding(get: { Double(store.serviceRadiusMiles) },
                        set: { store.serviceRadiusMiles = min(max(Int($0.rounded()), 5), 50) }), in: 5...50, step: 1)
                        .tint(DesignTokens.Colors.customerDeep)
                        .accessibilityLabel("Service radius")
                    Text("Use 50+ when you cover a wider service area.").designSupportingText()
                }
            }

            GroomerCaptioned(title: "Service location") {
                BeckonGroomingLocationModeSelector(selection: store.serviceLocationModes, selectionPolicy: .multiple,
                    perspective: .groomer, accent: .groomer) { store.serviceLocationModes = $0 }
            }
        }
    }

    private var visibility: some View {
        DesignSection(title: "Visibility", systemImage: "eye.fill", spacing: DesignTokens.Spacing.lg) {
            GroomerToggleRow(title: "Visible to authenticated customers",
                subtitle: "Customers can discover and receive offers from active groomer profiles.", isOn: $store.isActive,
                identifier: "groomer.profile.visible")
            if let profile = store.profile, profile.ratingCount > 0 || profile.isVerified {
                BeckonFlowLayout(spacing: DesignTokens.Spacing.sm, rowSpacing: DesignTokens.Spacing.sm) {
                    if let average = profile.exactRatingAverage {
                        BeckonStatusChip(.rating(average: average, count: profile.ratingCount))
                    }
                    if profile.isVerified { BeckonStatusChip(.verified) }
                }
            }
        }
    }
}

nonisolated enum GroomerProfileFocusTarget: String, CaseIterable, Hashable {
    case businessName = "groomer.profile.business-name.container"
    case biography = "groomer.profile.biography.container"
}
