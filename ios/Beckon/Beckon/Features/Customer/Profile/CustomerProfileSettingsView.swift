import PhotosUI
import SwiftUI
import UIKit

struct CustomerProfileSettingsView: View {
    @Bindable var store: CustomerProfileStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                CustomerAvatarEditorSection(store: store)

                BeckonCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        CustomerProfileTextField(
                            title: "Nickname",
                            text: $store.nickname,
                            prompt: "Nickname"
                        )
                        .textContentType(.nickname)

                        CustomerProfileTextField(
                            title: "Email",
                            text: $store.contactEmail,
                            prompt: "name@example.com"
                        )
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        CustomerProfileTextField(
                            title: "Phone",
                            text: $store.phoneNumber,
                            prompt: "(555) 555-5555"
                        )
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    }
                }

                BeckonCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Text("Address")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        BeckonAddressEditor(state: store.addressEditorState)
                    }
                }

                Button {
                    Task {
                        await store.saveProfile()
                    }
                } label: {
                    Text(store.isSaving ? "Saving..." : "Save Profile")
                }
                .buttonStyle(BeckonPrimaryButtonStyle(accent: .customer))
                .disabled(store.isSaving || store.isUploading)

                if store.shouldShowInitialLoading {
                    BeckonLoadingView(
                        title: "Loading Profile...",
                        message: "Fetching your saved customer details."
                    )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Profile Settings")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .background {
            CustomerProfileStatusView(store: store)
        }
        .accessibilityIdentifier("customer.profile.settings")
    }
}

struct CustomerAvatarImage: View {
    let data: Data?
    let size: CGFloat
    let placeholderSize: CGFloat

    var body: some View {
        BeckonModuleImage(data: data) {
            BeckonDefaultProfileAvatar(
                tone: .customer,
                symbolSize: placeholderSize
            )
        }
        .frame(width: size, height: size)
        .clipShape(DesignTokens.Shapes.circular)
        .overlay {
            Circle()
                .stroke(DesignTokens.Colors.customerPrimary.opacity(0.26), lineWidth: 2)
        }
        .accessibilityHidden(true)
    }
}

enum CustomerAvatarImageEncoder {
    static func displayablePayload(
        from data: Data,
        preferredContentType: CustomerAvatarPhotoContentType
    ) -> (data: Data, contentType: CustomerAvatarPhotoContentType)? {
        guard let image = UIImage(data: data) else { return nil }

        if preferredContentType == .png,
           let pngData = image.pngData(),
           UIImage(data: pngData) != nil {
            return (pngData, .png)
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.88),
              UIImage(data: jpegData) != nil else {
            return nil
        }

        return (jpegData, .jpeg)
    }
}

private struct CustomerAvatarEditorSection: View {
    @Bindable var store: CustomerProfileStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        let hasSavedPhoto = store.profile?.avatarPath != nil || store.avatarPhotoData != nil
        let photoStatusText = hasSavedPhoto ? "Photo saved to your profile." : "Add a profile photo."
        let photoActionTitle = hasSavedPhoto ? "Replace Photo" : "Upload Photo"

        BeckonPhotoEditorCard(
            title: "Profile Photo",
            statusText: photoStatusText,
            showsSavedIndicator: hasSavedPhoto,
            savedAccessibilityLabel: "Profile photo saved"
        ) {
            CustomerAvatarImage(
                data: store.avatarPhotoData,
                size: 96,
                placeholderSize: 38
            )
                .accessibilityHidden(true)
        } action: {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label(photoActionTitle, systemImage: "camera")
            }
            .buttonStyle(BeckonSecondaryButtonStyle(accent: .customer))
            .disabled(store.isBusy)
            .accessibilityIdentifier("customer.profile.avatar.upload")
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
            .compactMap(CustomerAvatarPhotoContentType.init(uniformType:))
            .first ?? .jpeg

        guard let payload = CustomerAvatarImageEncoder.displayablePayload(
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

private struct CustomerProfileTextField: View {
    let title: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            TextField(prompt, text: $text)
                .beckonFormField()
        }
    }
}

private struct CustomerProfileStatePicker: View {
    let title: String
    @Binding var selection: USStateCode?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Menu {
                Button("No State") {
                    selection = nil
                }

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

struct CustomerProfileStatusView: View {
    let store: CustomerProfileStore

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
        guard let errorMessage = store.errorMessage else { return nil }
        return BeckonGlobalFeedbackError(
            scope: .page("customer.profile"),
            sourceKey: "customer.profile.error",
            title: "Profile Update Failed",
            message: errorMessage
        )
    }

    private var progressPrompt: BeckonGlobalFeedbackProgress? {
        guard store.isSaving || store.isUploading else { return nil }
        return BeckonGlobalFeedbackProgress(
            scope: .operation("customer.profile.save"),
            sourceKey: "customer.profile.save-progress",
            title: store.isUploading ? "Uploading..." : "Saving...",
            tone: .customer
        )
    }
}
