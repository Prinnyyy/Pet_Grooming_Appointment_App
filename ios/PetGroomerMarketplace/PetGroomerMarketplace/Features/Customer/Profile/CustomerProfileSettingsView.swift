import PhotosUI
import SwiftUI
import UIKit

struct CustomerAccountView: View {
    let session: AuthSessionSnapshot
    let profile: MarketplaceProfile
    @Bindable var authenticationStore: AuthenticationStore
    @State private var store: CustomerProfileStore

    init(
        session: AuthSessionSnapshot,
        profile: MarketplaceProfile,
        authenticationStore: AuthenticationStore,
        repository: any CustomerProfileRepository,
        debugRecorder: AppDebugEventRecorder? = nil
    ) {
        self.session = session
        self.profile = profile
        self.authenticationStore = authenticationStore
        _store = State(
            initialValue: CustomerProfileStore(
                customerID: profile.userID,
                initialDisplayName: profile.displayName,
                sessionEmail: session.email,
                repository: repository,
                debugRecorder: debugRecorder
            )
        )
    }

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    AccountTabTitle("Account")

                    CustomerAccountProfileCard(
                        displayName: store.profileDisplayName,
                        detailText: store.profileDetailText,
                        avatarPhotoData: store.avatarPhotoData
                    )

                    GroomlyCard(padding: 0) {
                        CustomerAccountMenuLink(
                            title: "Profile Settings",
                            systemImage: "person.crop.circle"
                        ) {
                            CustomerProfileSettingsView(store: store)
                        }
                    }

                    if let errorMessage = authenticationStore.errorMessage {
                        GroomlyErrorBanner(
                            title: "Account action failed",
                            message: errorMessage
                        )
                        .accessibilityIdentifier("auth.error")
                    }

                    #if DEBUG
                    NavigationLink {
                        DebugPanelView(
                            diagnostics: DebugDiagnostics.current(
                                session: session,
                                profile: profile
                            )
                        )
                    } label: {
                        Label("Debug Console", systemImage: "ladybug")
                            .font(DesignTokens.Typography.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DesignTokens.Spacing.lg)
                            .background(DesignTokens.Colors.surfaceRaised)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: DesignTokens.CornerRadius.card,
                                    style: .continuous
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("account.debug-console")
                    #endif

                    Button(role: .destructive) {
                        Task {
                            await authenticationStore.signOut()
                        }
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Spacer(minLength: 0)

                            if authenticationStore.isSubmitting {
                                ProgressView()
                                    .tint(DesignTokens.Colors.error)
                            }

                            Text(
                                authenticationStore.isSubmitting
                                    ? "Signing Out..."
                                    : "Sign Out"
                            )
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.error)

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, DesignTokens.Spacing.md)
                    }
                    .buttonStyle(.plain)
                    .disabled(authenticationStore.isSubmitting)
                    .accessibilityIdentifier("auth.sign-out")
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.xl + DesignTokens.Spacing.xl)
            }
        }
        .task {
            await store.load()
        }
        .background {
            CustomerProfileStatusView(store: store)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("customer.account")
    }
}

private struct CustomerAccountProfileCard: View {
    let displayName: String
    let detailText: String
    let avatarPhotoData: Data?

    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.lg) {
                CustomerAvatarImage(
                    data: avatarPhotoData,
                    size: 84,
                    placeholderSize: 34
                )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(displayName)
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(detailText)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)

                    GroomlyStatusChip(
                        "Pet Owner",
                        systemImage: "pawprint.fill",
                        tone: .customer
                    )
                    .padding(.top, DesignTokens.Spacing.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CustomerAccountMenuLink<Destination: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                    .frame(width: 36)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CustomerProfileSettingsView: View {
    @Bindable var store: CustomerProfileStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                GroomlySectionHeader(
                    "Profile Settings",
                    subtitle: "Manage the customer details used across your account."
                )

                CustomerAvatarEditorSection(store: store)

                GroomlyCard {
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

                GroomlyCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Text("Address")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        CustomerProfileTextField(
                            title: "Street Address",
                            text: $store.streetAddress,
                            prompt: "Street Address"
                        )
                        .textContentType(.streetAddressLine1)

                        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                            CustomerProfileTextField(
                                title: "City",
                                text: $store.city,
                                prompt: "City"
                            )
                            .textContentType(.addressCity)

                            CustomerProfileStatePicker(
                                title: "State",
                                selection: $store.stateCode
                            )
                            .frame(width: 100)
                        }

                        CustomerProfileTextField(
                            title: "ZIP Code",
                            text: $store.zipCode,
                            prompt: "ZIP Code"
                        )
                        .textContentType(.postalCode)
                        .keyboardType(.numbersAndPunctuation)
                    }
                }

                if store.shouldShowInitialLoading {
                    GroomlyLoadingView(
                        title: "Loading Profile...",
                        message: "Fetching your saved customer details."
                    )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, 120)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Profile Settings")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    await store.saveProfile()
                }
            } label: {
                Text(store.isSaving ? "Saving..." : "Save Profile")
            }
            .buttonStyle(GroomlyPrimaryButtonStyle(accent: .customer))
            .disabled(store.isSaving || store.isUploading)
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(.ultraThinMaterial)
        }
        .background {
            CustomerProfileStatusView(store: store)
        }
        .accessibilityIdentifier("customer.profile.settings")
    }
}

private struct CustomerAvatarImage: View {
    let data: Data?
    let size: CGFloat
    let placeholderSize: CGFloat

    var body: some View {
        GroomlyModuleImage(data: data) {
            GroomlyDefaultProfileAvatar(
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

        GroomlyCard {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
                ZStack(alignment: .bottomTrailing) {
                    CustomerAvatarImage(
                        data: store.avatarPhotoData,
                        size: 96,
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
                        Label(photoActionTitle, systemImage: "camera")
                    }
                    .buttonStyle(GroomlySecondaryButtonStyle(accent: .customer))
                    .disabled(store.isBusy)
                    .accessibilityIdentifier("customer.profile.avatar.upload")
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
                .groomlyFormField()
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
                .groomlyFormField()
            }
        }
    }
}

private struct CustomerProfileStatusView: View {
    let store: CustomerProfileStore

    var body: some View {
        GroomlyGlobalFeedbackForwarder(
            noticeMessage: store.noticeMessage,
            clearNotice: { message in
                guard store.noticeMessage == message else { return }
                store.noticeMessage = nil
            },
            error: errorPrompt,
            progress: progressPrompt
        )
    }

    private var errorPrompt: GroomlyGlobalFeedbackError? {
        guard let errorMessage = store.errorMessage else { return nil }
        return GroomlyGlobalFeedbackError(
            scope: .page("customer.profile"),
            sourceKey: "customer.profile.error",
            title: "Profile Update Failed",
            message: errorMessage
        )
    }

    private var progressPrompt: GroomlyGlobalFeedbackProgress? {
        guard store.isSaving || store.isUploading else { return nil }
        return GroomlyGlobalFeedbackProgress(
            scope: .operation("customer.profile.save"),
            sourceKey: "customer.profile.save-progress",
            title: store.isUploading ? "Uploading..." : "Saving...",
            tone: .customer
        )
    }
}
