import Combine
import MapKit
import PhotosUI
import SwiftUI
import UIKit

struct GroomerProfileManagementView: View {
    @State private var store: GroomerProfileStore
    let accountContent: AnyView?
    let onSignOut: (() -> Void)?

    init(
        groomerID: UUID,
        repository: any GroomerProfileRepository,
        accountContent: AnyView? = nil,
        onSignOut: (() -> Void)? = nil
    ) {
        _store = State(
            initialValue: GroomerProfileStore(
                groomerID: groomerID,
                repository: repository
            )
        )
        self.accountContent = accountContent
        self.onSignOut = onSignOut
    }

    var body: some View {
        @Bindable var store = store

        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            if store.isLoading, store.profile == nil {
                GroomlyLoadingView(
                    title: "Loading Groomer Profile…",
                    message: "We are preparing your profile, services, and portfolio settings.",
                    accent: .groomer
                )
                .accessibilityIdentifier("groomer.profile.loading")
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomerAccountHomeView(
                            store: store,
                            accountContent: accountContent,
                            onSignOut: onSignOut
                        )
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.xl)
                    .padding(.bottom, 120)
                }
                .accessibilityIdentifier("groomer.account.home")
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            GroomerProfileStatusView(store: store)
        }
        .sheet(isPresented: $store.isShowingServiceForm) {
            GroomerServiceFormView(store: store)
        }
        .task {
            await store.load()
        }
    }
}

private struct GroomerAccountHomeView: View {
    @Bindable var store: GroomerProfileStore
    let accountContent: AnyView?
    let onSignOut: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Account")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DesignTokens.Spacing.sm)

            GroomerAccountProfileCard(
                profile: store.profile,
                avatarPhotoData: store.avatarPhotoData
            )

            VStack(spacing: 0) {
                GroomerAccountMenuLink(
                    title: "Edit Profile",
                    systemImage: "pencil",
                    isFirst: true
                ) {
                    GroomerProfileEditorView(store: store)
                }

                Divider()
                    .overlay(DesignTokens.Colors.divider)
                    .padding(.leading, 72)

                GroomerAccountMenuLink(
                    title: "Services",
                    systemImage: "scissors"
                ) {
                    GroomerServicesEditorView(store: store)
                }

                Divider()
                    .overlay(DesignTokens.Colors.divider)
                    .padding(.leading, 72)

                GroomerAccountMenuLink(
                    title: "Portfolio",
                    systemImage: "photo.on.rectangle"
                ) {
                    GroomerPortfolioEditorView(store: store)
                }

                Divider()
                    .overlay(DesignTokens.Colors.divider)
                    .padding(.leading, 72)

                GroomerAccountMenuLink(
                    title: "Availability",
                    systemImage: "calendar",
                    isLast: true
                ) {
                    GroomerAvailabilityEditorView(store: store)
                }
            }
            .background(DesignTokens.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
            }

            signOutControl
                .padding(.top, DesignTokens.Spacing.lg)
        }
    }

    @ViewBuilder
    private var signOutControl: some View {
        if let onSignOut {
            Button(role: .destructive) {
                onSignOut()
            } label: {
                Text("Sign Out")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.md)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("groomer.account.sign-out")
        } else if let accountContent {
            NavigationLink {
                accountContent
            } label: {
                Text("Sign Out")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.md)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct GroomerAccountProfileCard: View {
    let profile: GroomerProfile?
    let avatarPhotoData: Data?

    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.lg) {
                GroomerAvatarImage(
                    data: avatarPhotoData,
                    size: 84,
                    cornerRadius: 24,
                    placeholderSize: 34
                )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(profile?.businessName ?? "Groomer Profile")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(ratingSummary)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    GroomlyStatusChip(
                        "Groomer",
                        systemImage: "scissors",
                        tone: .groomer
                    )
                    .padding(.top, DesignTokens.Spacing.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var ratingSummary: String {
        guard let profile, profile.ratingCount > 0 else {
            return "★ New profile"
        }

        return "★ \(profile.ratingAverage.formatted(.number.precision(.fractionLength(1)))) · \(profile.ratingCount) review\(profile.ratingCount == 1 ? "" : "s")"
    }
}

private struct GroomerAccountMenuLink<Destination: View>: View {
    let title: String
    let systemImage: String
    var isFirst = false
    var isLast = false
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
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

private struct GroomerAvatarImage: View {
    let data: Data?
    let size: CGFloat
    let cornerRadius: CGFloat
    let placeholderSize: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DesignTokens.Colors.groomerAccent.opacity(0.28),
                    DesignTokens.Colors.customerPrimary.opacity(0.34),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text("👩🏻")
                    .font(.system(size: placeholderSize))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private var image: UIImage? {
        guard let data else { return nil }
        return UIImage(data: data)
    }
}

private struct GroomerProfileEditorView: View {
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
        .accessibilityIdentifier("groomer.profile.edit")
    }
}

private struct GroomerServicesEditorView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        ScrollView {
            GroomerServicesSection(store: store)
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.lg)
                .padding(.bottom, 120)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Services")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("groomer.services.edit")
    }
}

private struct GroomerPortfolioEditorView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        ScrollView {
            GroomerPortfolioSection(store: store)
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.lg)
                .padding(.bottom, 120)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Portfolio")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("groomer.portfolio.edit")
    }
}

private struct GroomerAvailabilityEditorView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                GroomlySectionHeader(
                    "Availability",
                    subtitle: "Choose the days and hours customers can request appointments with you."
                )

                GroomlyCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            Image(systemName: "clock")
                                .font(DesignTokens.Typography.headline)
                                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                                .frame(width: 42, height: 42)
                                .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text("Weekly Schedule")
                                    .font(DesignTokens.Typography.headline)
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                                Text(store.availabilityTimezone)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(spacing: DesignTokens.Spacing.md) {
                            ForEach($store.availabilityDayStates) { $dayState in
                                GroomerAvailabilityDayRow(dayState: $dayState)
                            }
                        }
                    }
                }

                Button {
                    Task {
                        await store.saveAvailability()
                    }
                } label: {
                    if store.isSaving {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ProgressView()
                                .tint(DesignTokens.Colors.surface)
                            Text("Saving…")
                        }
                    } else {
                        Label("Save Availability", systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(GroomlyPrimaryButtonStyle(accent: .groomer))
                .disabled(store.isBusy)
                .accessibilityIdentifier("groomer.availability.save")

                if let errorMessage = store.errorMessage {
                    GroomlyErrorBanner(
                        title: "Availability Could Not Be Saved",
                        message: errorMessage
                    )
                    .accessibilityIdentifier("groomer.availability.error")
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, 120)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Availability")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("groomer.availability.edit")
    }
}

private struct GroomerAvailabilityDayRow: View {
    @Binding var dayState: GroomerAvailabilityDayState

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(dayState.weekday.shortTitle)
                    .font(DesignTokens.Typography.body.weight(.bold))
                    .foregroundStyle(
                        dayState.isEnabled
                            ? DesignTokens.Colors.groomerAccentDark
                            : DesignTokens.Colors.textSecondary
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        dayState.isEnabled
                            ? DesignTokens.Colors.groomerAccent.opacity(0.16)
                            : DesignTokens.Colors.borderSoft.opacity(0.5)
                    )
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(dayState.weekday.title)
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text(dayState.summary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle(dayState.weekday.title, isOn: $dayState.isEnabled)
                    .labelsHidden()
                    .tint(DesignTokens.Colors.groomerAccent)
            }

            if dayState.isEnabled {
                HStack(spacing: DesignTokens.Spacing.md) {
                    GroomerAvailabilityTimeMenu(
                        title: "Start",
                        minutes: $dayState.startMinutes
                    )

                    GroomerAvailabilityTimeMenu(
                        title: "End",
                        minutes: $dayState.endMinutes
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .stroke(
                    dayState.isEnabled
                        ? DesignTokens.Colors.groomerAccent.opacity(0.5)
                        : DesignTokens.Colors.borderSoft,
                    lineWidth: dayState.isEnabled ? 1.5 : 1
                )
        }
        .animation(.easeInOut(duration: 0.18), value: dayState.isEnabled)
    }
}

private struct GroomerAvailabilityTimeMenu: View {
    let title: String
    @Binding var minutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Menu {
                ForEach(Self.timeOptions, id: \.self) { option in
                    Button(GroomerAvailabilityWindow.displayTime(fromMinutes: option)) {
                        minutes = option
                    }
                }
            } label: {
                HStack {
                    Text(GroomerAvailabilityWindow.displayTime(fromMinutes: minutes))
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: DesignTokens.Spacing.xs)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.borderSoft.opacity(0.36))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let timeOptions: [Int] = stride(
        from: 6 * 60,
        through: 22 * 60,
        by: 30
    )
    .map { $0 }
}

private struct GroomerAvatarEditorSection: View {
    @Bindable var store: GroomerProfileStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        GroomlyCard {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
                ZStack(alignment: .bottomTrailing) {
                    GroomerAvatarImage(
                        data: store.avatarPhotoData,
                        size: 94,
                        cornerRadius: 28,
                        placeholderSize: 38
                    )

                    if store.profile?.avatarPath != nil {
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

                        Text(store.profile?.avatarPath == nil ? "Add a clear face photo." : "Photo saved to your profile.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(
                            store.profile?.avatarPath == nil ? "Upload Photo" : "Replace Photo",
                            systemImage: "camera"
                        )
                    }
                    .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer))
                    .disabled(store.isBusy)
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

        await store.uploadAvatarPhoto(data: data, contentType: contentType)
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

private struct GroomerServicesSection: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader(
                "Services",
                subtitle: "Empty size selection means the service accepts all pet sizes."
            ) {
                Button {
                    store.startCreateService()
                } label: {
                    Label("Add Service", systemImage: "plus")
                }
                .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer, isFullWidth: false))
                .disabled(store.isBusy)
                .accessibilityIdentifier("groomer.services.add")
            }

            if store.services.isEmpty {
                GroomlyEmptyState(
                    title: "No Services Yet",
                    message: "Add services before responding to future requests.",
                    systemImage: "scissors",
                    accent: .groomer
                ) {
                    Button {
                        store.startCreateService()
                    } label: {
                        Label("Add Service", systemImage: "plus")
                    }
                    .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer))
                    .disabled(store.isBusy)
                }
                .accessibilityIdentifier("groomer.services.empty")
            } else {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(store.services) { service in
                        GroomerServiceRow(
                            service: service,
                            store: store
                        )
                    }
                }
            }
        }
    }
}

private struct GroomerServiceRow: View {
    let service: GroomerService
    @Bindable var store: GroomerProfileStore

    var body: some View {
        GroomlyCard {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(service.title)
                                .font(DesignTokens.Typography.headline)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("$\(service.basePrice, specifier: "%.2f") • \(service.durationMinutes) min")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        GroomlyStatusChip(
                            service.isActive ? "Visible" : "Hidden",
                            systemImage: service.isActive ? "eye.fill" : "eye.slash",
                            tone: service.isActive ? .success : .neutral
                        )
                    }

                    Label(service.acceptedPetSizeSummary, systemImage: "pawprint")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    if let description = service.description {
                        Text(description)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Menu {
                    Button("Edit") {
                        store.startEditService(service)
                    }

                    Button("Delete", role: .destructive) {
                        Task {
                            await store.deleteService(service)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(DesignTokens.Typography.title)
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                        .accessibilityLabel("Service actions")
                }
                .disabled(store.isBusy)
            }
        }
    }
}

private struct GroomerProfileTextField: View {
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

private struct GroomerProfileAddressSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
}

private struct GroomerProfileAddressCompletion<Completion> {
    let title: String
    let subtitle: String
    let completion: Completion
}

private enum GroomerProfileAddressSuggestionBuilder {
    static func build<Completion>(
        from completions: [GroomerProfileAddressCompletion<Completion>],
        limit: Int = 5
    ) -> (
        suggestions: [GroomerProfileAddressSuggestion],
        completionsByID: [String: Completion]
    ) {
        var seenKeys: Set<String> = []
        var suggestions: [GroomerProfileAddressSuggestion] = []
        var completionsByID: [String: Completion] = [:]

        for completion in completions where suggestions.count < limit {
            let title = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let key = "\(title)|\(subtitle)"
            guard seenKeys.insert(key).inserted else { continue }

            let suggestion = GroomerProfileAddressSuggestion(
                id: key,
                title: title,
                subtitle: subtitle
            )
            suggestions.append(suggestion)
            completionsByID[suggestion.id] = completion.completion
        }

        return (suggestions, completionsByID)
    }
}

private struct GroomerProfileResolvedAddress {
    let streetAddress: String
    let city: String
    let stateCode: USStateCode
    let zipCode: String
}

private final class GroomerProfileAddressSearch:
    NSObject,
    ObservableObject,
    MKLocalSearchCompleterDelegate
{
    @Published private(set) var suggestions: [GroomerProfileAddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var completionsByID: [String: MKLocalSearchCompletion] = [:]
    private var lastQueryFragment = ""

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(
        street: String,
        city: String,
        stateCode: USStateCode?
    ) {
        let trimmedStreet = street.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedStreet.count >= 3 else {
            suggestions = []
            completionsByID = [:]
            updateQueryFragmentIfNeeded("")
            return
        }

        let query = [
            trimmedStreet,
            city.trimmingCharacters(in: .whitespacesAndNewlines),
            stateCode?.rawValue ?? "",
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")

        updateQueryFragmentIfNeeded(query)
    }

    private func updateQueryFragmentIfNeeded(_ query: String) {
        guard query != lastQueryFragment else { return }
        lastQueryFragment = query
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let result = GroomerProfileAddressSuggestionBuilder.build(
            from: completer.results.map { completion in
                GroomerProfileAddressCompletion(
                    title: completion.title,
                    subtitle: completion.subtitle,
                    completion: completion
                )
            }
        )

        DispatchQueue.main.async {
            self.suggestions = result.suggestions
            self.completionsByID = result.completionsByID
        }
    }

    func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: any Error
    ) {
        DispatchQueue.main.async {
            self.suggestions = []
            self.completionsByID = [:]
        }
    }

    func resolve(
        _ suggestion: GroomerProfileAddressSuggestion
    ) async -> GroomerProfileResolvedAddress? {
        guard let completion = completionsByID[suggestion.id] else { return nil }

        let request = MKLocalSearch.Request(completion: completion)
        guard
            let mapItem = try? await MKLocalSearch(request: request).start().mapItems.first,
            let state = mapItem.placemark.administrativeArea,
            let stateCode = USStateCode(rawValue: state.uppercased()),
            let zipCode = mapItem.placemark.postalCode?.trimmingCharacters(in: .whitespacesAndNewlines),
            !zipCode.isEmpty
        else {
            return nil
        }

        let streetAddress = [
            mapItem.placemark.subThoroughfare,
            mapItem.placemark.thoroughfare,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")

        guard !streetAddress.isEmpty else { return nil }

        return GroomerProfileResolvedAddress(
            streetAddress: streetAddress,
            city: mapItem.placemark.locality ?? "",
            stateCode: stateCode,
            zipCode: zipCode
        )
    }
}

private struct GroomlyToggleRow: View {
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

private struct GroomerServiceSizeToggleRow: View {
    let size: GroomerServicePetSize
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "pawprint")
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                .frame(
                    width: DesignTokens.Spacing.xl,
                    height: DesignTokens.Spacing.xl
                )
                .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            Text(size.title)
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(size.title, isOn: $isOn)
                .labelsHidden()
                .tint(DesignTokens.Colors.groomerAccent)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GroomerServiceTypePicker: View {
    @Binding var selection: GroomingServiceType

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Service Type")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            VStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(GroomingServiceType.allCases) { type in
                    Button {
                        selection = type
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            Image(systemName: "scissors")
                                .font(DesignTokens.Typography.caption.weight(.bold))
                                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                                .frame(width: DesignTokens.Spacing.xl, height: DesignTokens.Spacing.xl)
                                .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text(type.title)
                                    .font(DesignTokens.Typography.body.weight(.semibold))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                                Text(type.subtitle)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if selection == type {
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
                                selection == type
                                    ? DesignTokens.Colors.groomerAccent
                                    : DesignTokens.Colors.borderSoft,
                                lineWidth: selection == type ? 2 : 1
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ProfileBadges: View {
    let profile: GroomerProfile

    var body: some View {
        if profile.ratingCount > 0 || profile.isVerified {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if profile.ratingCount > 0 {
                    GroomlyStatusChip(
                        "\(profile.ratingAverage.formatted(.number.precision(.fractionLength(2)))) from \(profile.ratingCount) review\(profile.ratingCount == 1 ? "" : "s")",
                        systemImage: "star.fill",
                        tone: .warning
                    )
                }

                if profile.isVerified {
                    GroomlyStatusChip(
                        "Verified",
                        systemImage: "checkmark.seal.fill",
                        tone: .success
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct GroomerPortfolioSection: View {
    @Bindable var store: GroomerProfileStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader(
                "Portfolio",
                subtitle: "Images upload to the private groomer-portfolio bucket and stay metadata-only here."
            ) {
                addPhotoPicker(isFullWidth: false)
            }

            if store.isUploading {
                GroomerPortfolioUpdatingCard()
            }

            if store.portfolioPhotos.isEmpty {
                GroomlyEmptyState(
                    title: "No Portfolio Photos",
                    message: "Add work examples after completing your profile. This screen shows stored metadata only.",
                    systemImage: "photo.on.rectangle",
                    accent: .groomer
                )
                .accessibilityIdentifier("groomer.portfolio.empty")
            } else {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(store.sortedPortfolioPhotos()) { photo in
                        GroomerPortfolioPhotoRow(
                            photo: photo,
                            store: store
                        )
                    }
                }
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
            .compactMap(GroomerPortfolioPhotoContentType.init(uniformType:))
            .first ?? .jpeg

        await store.uploadPortfolioPhoto(
            data: data,
            contentType: contentType
        )
    }

    private func addPhotoPicker(isFullWidth: Bool) -> some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images
        ) {
            Label("Add Photo", systemImage: "plus")
        }
        .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer, isFullWidth: isFullWidth))
        .disabled(store.isBusy)
        .accessibilityIdentifier("groomer.portfolio.add")
    }
}

private struct GroomerPortfolioUpdatingCard: View {
    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ProgressView()
                    .tint(DesignTokens.Colors.groomerAccent)

                Text("Updating portfolio metadata…")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct GroomerPortfolioPhotoRow: View {
    let photo: GroomerPortfolioPhoto
    @Bindable var store: GroomerProfileStore

    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "photo.on.rectangle")
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
                        Text(photo.fileName)
                            .font(DesignTokens.Typography.body.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .lineLimit(1)

                        if let caption = photo.caption {
                            Text(caption)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("No Caption Metadata")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(role: .destructive) {
                        Task {
                            await store.deletePortfolioPhoto(photo)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.error)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.error.opacity(0.08))
                    .overlay {
                        DesignTokens.Shapes.chip
                            .stroke(DesignTokens.Colors.error.opacity(0.26), lineWidth: 1)
                    }
                    .clipShape(DesignTokens.Shapes.chip)
                    .disabled(store.isBusy)
                }

                Divider()
                    .overlay(DesignTokens.Colors.divider)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    GroomerPortfolioMetadataRow(
                        title: "Bucket",
                        value: photo.storageBucket,
                        systemImage: "shippingbox"
                    )

                    GroomerPortfolioMetadataRow(
                        title: "Storage Path",
                        value: photo.storagePath,
                        systemImage: "folder"
                    )

                    GroomerPortfolioMetadataRow(
                        title: "Sort Order",
                        value: "\(photo.sortOrder)",
                        systemImage: "arrow.up.arrow.down"
                    )
                }
            }
        }
    }
}

private struct GroomerPortfolioMetadataRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .frame(width: DesignTokens.Spacing.lg)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text(value)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GroomerServiceFormView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlySectionHeader(
                            store.serviceFormTitle,
                            subtitle: "Define the service customers can review when you make offers."
                        )

                        GroomlyCard {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                                GroomerServiceTypePicker(
                                    selection: $store.serviceType
                                )

                                GroomerProfileTextField(
                                    title: "Description",
                                    text: $store.serviceDescription,
                                    prompt: "Description",
                                    axis: .vertical
                                )
                                .lineLimit(2...4)

                                GroomerProfileTextField(
                                    title: "Base Price",
                                    text: $store.serviceBasePrice,
                                    prompt: "Base Price"
                                )
                                .keyboardType(.decimalPad)

                                GroomerProfileTextField(
                                    title: "Duration in Minutes",
                                    text: $store.serviceDurationMinutes,
                                    prompt: "Duration in Minutes"
                                )
                                .keyboardType(.numberPad)

                                GroomlyToggleRow(
                                    title: "Visible to Customers",
                                    subtitle: "Hidden services stay saved but do not appear as active options.",
                                    systemImage: "eye",
                                    isOn: $store.serviceIsActive
                                )
                            }
                        }

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            GroomlySectionHeader(
                                "Accepted pet sizes",
                                subtitle: "Leave all sizes off when this service accepts every pet size."
                            )

                            GroomlyCard {
                                VStack(spacing: DesignTokens.Spacing.md) {
                                    ForEach(GroomerServicePetSize.allCases) { size in
                                        GroomerServiceSizeToggleRow(
                                            size: size,
                                            isOn: Binding(
                                                get: {
                                                    store.selectedServiceSizes.contains(size)
                                                },
                                                set: { isSelected in
                                                    if isSelected {
                                                        store.selectedServiceSizes.insert(size)
                                                    } else {
                                                        store.selectedServiceSizes.remove(size)
                                                    }
                                                }
                                            )
                                        )

                                        if size.id != GroomerServicePetSize.allCases.last?.id {
                                            Divider()
                                                .overlay(DesignTokens.Colors.divider)
                                        }
                                    }
                                }
                            }
                        }

                        if let errorMessage = store.errorMessage {
                            GroomlyErrorBanner(
                                title: "Service Could Not Be Saved",
                                message: errorMessage
                            )
                            .accessibilityIdentifier("groomer.services.form-error")
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.vertical, DesignTokens.Spacing.lg)
                }
            }
            .navigationTitle(store.serviceFormTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.cancelServiceForm()
                    }
                    .disabled(store.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await store.saveService()
                        }
                    }
                    .disabled(store.isSaving)
                }
            }
        }
        .interactiveDismissDisabled(store.isSaving)
    }
}

private struct GroomerProfileStatusView: View {
    let store: GroomerProfileStore

    var body: some View {
        VStack(spacing: 0) {
            GroomlyNoticeForwarder(message: store.noticeMessage) { message in
                guard store.noticeMessage == message else { return }
                store.noticeMessage = nil
            }

            if hasInlineStatus {
                inlineStatus
            }
        }
    }

    private var inlineStatus: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            if store.isSaving || store.isUploading {
                GroomlyStatusProgressToast(
                    store.isUploading ? "Uploading…" : "Saving…",
                    tint: DesignTokens.Colors.groomerAccent
                )
            }

            if let errorMessage = store.errorMessage,
               !store.isShowingServiceForm {
                GroomlyErrorBanner(
                    title: "Profile Update Failed",
                    message: errorMessage
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .animation(.easeInOut(duration: 0.24), value: hasInlineStatus)
    }

    private var hasInlineStatus: Bool {
        store.isSaving ||
            store.isUploading ||
            (store.errorMessage != nil && !store.isShowingServiceForm)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GroomerProfileManagementView(
            groomerID: UUID(),
            repository: GroomerProfilePreviewRepository()
        )
    }
}

@MainActor
private final class GroomerProfilePreviewRepository: GroomerProfileRepository {
    private let groomerID = UUID()
    private var storedProfile: GroomerProfile
    private var storedServices: [GroomerService]
    private var storedPhotos: [GroomerPortfolioPhoto] = []
    private var storedAvailability: [GroomerAvailabilityWindow] = []

    init() {
        storedProfile = GroomerProfile(
            userID: groomerID,
            businessName: "Fresh Coat Grooming",
            bio: "Calm, one-on-one grooming for small and medium dogs.",
            yearsExperience: 5,
            baseStreetAddress: "123 Pine Street",
            baseCity: "Seattle",
            baseState: "WA",
            baseZipCode: "98101",
            serviceRadiusMiles: 12,
            serviceLocationMode: .groomerComesToCustomer,
            serviceLocationModes: [.groomerComesToCustomer, .customerComesToGroomer],
            ratingAverage: 0,
            ratingCount: 0,
            isActive: false,
            isVerified: false
        )
        storedServices = [
            GroomerService(
                id: UUID(),
                groomerID: groomerID,
                serviceType: .fullGroom,
                title: "Full Groom",
                description: "Bath, haircut, nails, and ear cleaning.",
                basePrice: 95,
                durationMinutes: 120,
                acceptedPetSizes: [.small, .medium],
                isActive: true
            ),
        ]
        storedAvailability = [
            GroomerAvailabilityWindow(
                id: UUID(),
                groomerID: groomerID,
                weekday: .monday,
                startMinutes: 9 * 60,
                endMinutes: 17 * 60,
                isEnabled: true,
                timezone: TimeZone.current.identifier
            ),
            GroomerAvailabilityWindow(
                id: UUID(),
                groomerID: groomerID,
                weekday: .tuesday,
                startMinutes: 9 * 60,
                endMinutes: 17 * 60,
                isEnabled: true,
                timezone: TimeZone.current.identifier
            ),
        ]
    }

    func profile(groomerID: UUID) async throws -> GroomerProfile {
        storedProfile
    }

    func services(groomerID: UUID) async throws -> [GroomerService] {
        storedServices
    }

    func portfolioPhotos(groomerID: UUID) async throws -> [GroomerPortfolioPhoto] {
        storedPhotos
    }

    func availabilityWindows(groomerID: UUID) async throws -> [GroomerAvailabilityWindow] {
        storedAvailability
    }

    func updateProfile(
        groomerID: UUID,
        draft: GroomerProfileDraft
    ) async throws -> GroomerProfile {
        storedProfile = GroomerProfile(
            userID: groomerID,
            businessName: draft.businessName,
            bio: draft.bio,
            yearsExperience: draft.yearsExperience,
            baseStreetAddress: draft.baseStreetAddress,
            baseCity: draft.baseCity,
            baseState: draft.baseStateCode?.rawValue,
            baseZipCode: draft.baseZipCode,
            serviceRadiusMiles: draft.serviceRadiusMiles,
            serviceLocationMode: draft.serviceLocationMode,
            serviceLocationModes: draft.serviceLocationModes,
            ratingAverage: storedProfile.ratingAverage,
            ratingCount: storedProfile.ratingCount,
            isActive: draft.isActive,
            isVerified: storedProfile.isVerified
        )
        return storedProfile
    }

    func createService(
        groomerID: UUID,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        let service = GroomerService(
            id: UUID(),
            groomerID: groomerID,
            serviceType: draft.serviceType,
            title: draft.title,
            description: draft.description,
            basePrice: draft.basePrice,
            durationMinutes: draft.durationMinutes,
            acceptedPetSizes: draft.acceptedPetSizes,
            isActive: draft.isActive
        )
        storedServices.insert(service, at: 0)
        return service
    }

    func updateService(
        service: GroomerService,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        GroomerService(
            id: service.id,
            groomerID: service.groomerID,
            serviceType: draft.serviceType,
            title: draft.title,
            description: draft.description,
            basePrice: draft.basePrice,
            durationMinutes: draft.durationMinutes,
            acceptedPetSizes: draft.acceptedPetSizes,
            isActive: draft.isActive
        )
    }

    func deleteService(_ service: GroomerService) async throws {}

    func uploadPortfolioPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerPortfolioPhotoContentType,
        caption: String?
    ) async throws -> GroomerPortfolioPhoto {
        GroomerPortfolioPhoto(
            id: UUID(),
            groomerID: groomerID,
            storageBucket: "groomer-portfolio",
            storagePath: GroomerPortfolioPhotoPath.make(
                groomerID: groomerID,
                contentType: contentType
            ),
            caption: caption,
            sortOrder: 0
        )
    }

    func deletePortfolioPhoto(_ photo: GroomerPortfolioPhoto) async throws {}

    func uploadAvatarPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerAvatarPhotoContentType
    ) async throws -> String {
        let path = GroomerAvatarPhotoPath.make(
            groomerID: groomerID,
            contentType: contentType
        )
        storedProfile.avatarPath = path
        return path
    }

    func avatarPhotoData(storagePath: String) async throws -> Data {
        Data()
    }

    func replaceAvailability(
        groomerID: UUID,
        drafts: [GroomerAvailabilityDraft]
    ) async throws -> [GroomerAvailabilityWindow] {
        storedAvailability = drafts.map {
            GroomerAvailabilityWindow(
                id: UUID(),
                groomerID: groomerID,
                weekday: $0.weekday,
                startMinutes: $0.startMinutes,
                endMinutes: $0.endMinutes,
                isEnabled: $0.isEnabled,
                timezone: $0.timezone
            )
        }
        return storedAvailability
    }
}
#endif
