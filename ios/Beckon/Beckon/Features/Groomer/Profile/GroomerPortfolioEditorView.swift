import PhotosUI
import SwiftUI

struct GroomerPortfolioEditorView: View {
    @Bindable var store: GroomerProfileStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        let presentation = GroomerPortfolioWorkspacePresentation(
            photoCount: store.portfolioPhotos.count,
            isUploading: store.isUploading,
            isBusy: store.isBusy
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                GroomerPortfolioGallerySection(
                    photos: store.sortedPortfolioPhotos(),
                    store: store,
                    presentation: presentation
                )
            }
            .beckonPageInsets()
        }
        .accessibilityIdentifier("groomer.portfolio.edit")
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Portfolio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addPhotoPicker(disabled: presentation.isAddDisabled)
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

    private func addPhotoPicker(disabled: Bool) -> some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images
        ) {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Add portfolio photo")
        .accessibilityIdentifier("groomer.portfolio.add")
        .disabled(disabled)
    }
}

private struct GroomerPortfolioGallerySection: View {
    let photos: [GroomerPortfolioPhoto]
    @Bindable var store: GroomerProfileStore
    let presentation: GroomerPortfolioWorkspacePresentation

    var body: some View {
        BeckonSection(
            "Work Gallery",
            subtitle: "Show customers the grooming work that represents your skills."
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                if let uploadStatus = presentation.uploadStatus {
                    BeckonGroupedSurface {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            ProgressView()
                                .tint(DesignTokens.Colors.groomerAccent)

                            Text(uploadStatus)
                                .font(DesignTokens.Typography.supporting)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }
                        .padding(DesignTokens.Layout.surfaceInset)
                    }
                    .accessibilityElement(children: .combine)
                }

                if photos.isEmpty {
                    GroomerPortfolioEmptyState()
                        .accessibilityIdentifier("groomer.portfolio.empty")
                } else {
                    LazyVGrid(
                        columns: Self.photoGridColumns,
                        alignment: .leading,
                        spacing: DesignTokens.Spacing.lg
                    ) {
                        ForEach(photos) { photo in
                            NavigationLink {
                                GroomerPortfolioPhotoDetailView(
                                    photo: photo,
                                    store: store
                                )
                            } label: {
                                GroomerPortfolioPhotoTile(
                                    photo: photo,
                                    store: store
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("groomer.portfolio.photo-card")
                        }
                    }
                }
            }
        } trailing: {
                Text(presentation.photoSummary)
                    .font(DesignTokens.Typography.status)
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .lineLimit(1)
        }
    }

    private static let photoGridColumns = [
        GridItem(.flexible(), spacing: DesignTokens.Spacing.md),
        GridItem(.flexible(), spacing: DesignTokens.Spacing.md),
    ]
}

private struct GroomerPortfolioEmptyState: View {
    var body: some View {
        BeckonGroupedSurface {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "photo.on.rectangle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("No work photos")
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text("Add finished grooming work to give customers a clear view of your style.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }
}

private struct GroomerPortfolioPhotoTile: View {
    let photo: GroomerPortfolioPhoto
    @Bindable var store: GroomerProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            GroomerPortfolioPhotoArtwork(
                data: store.portfolioPhotoData(for: photo),
                isUnavailable: store.isPortfolioPhotoDataUnavailable(photo)
            )

            Text(captionText ?? "Work photo")
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Text(store.portfolioFitTagSummary(for: photo))
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .lineLimit(2)

            Label("Edit fit notes", systemImage: "chevron.right")
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var captionText: String? {
        guard let caption = photo.caption?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !caption.isEmpty else {
            return nil
        }
        return caption
    }
}

private struct GroomerPortfolioPhotoDetailView: View {
    let photo: GroomerPortfolioPhoto
    @Bindable var store: GroomerProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        let presentation = GroomerPortfolioFitNotesPresentation(
            selectedTagCount: store.selectedPortfolioFitTagIDsByPhotoID[photo.id]?.count ?? 0,
            maximumTagCount: GroomerPortfolioFitTag.maximumTagsPerPhoto,
            isSaving: store.isSaving,
            isBusy: store.isBusy || !store.canEditPortfolioTags
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                GroomerPortfolioPhotoArtwork(
                    data: store.portfolioPhotoData(for: photo),
                    isUnavailable: store.isPortfolioPhotoDataUnavailable(photo),
                    aspectRatio: 4 / 3
                )
                .accessibilityIdentifier("groomer.portfolio.photo-artwork")

                GroomerPortfolioPhotoDetailSummary(
                    title: captionText ?? "Work photo",
                    fitNoteSummary: store.portfolioFitTagSummary(for: photo)
                )

                GroomerPortfolioFitNotesEditorSection(
                    photo: photo,
                    store: store,
                    presentation: presentation
                )
            }
            .beckonPageInsets()
        }
        .accessibilityIdentifier("groomer.portfolio.detail")
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Portfolio Photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GroomerPortfolioFitNotesSaveBar(
                presentation: presentation,
                showDeleteConfirmation: { isShowingDeleteConfirmation = true },
                save: saveFitNotes
            )
        }
        .confirmationDialog(
            "Delete this portfolio photo?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Photo", role: .destructive, action: deletePhoto)
        } message: {
            Text("This removes the photo and its fit notes from your portfolio.")
        }
    }

    private var captionText: String? {
        guard let caption = photo.caption?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !caption.isEmpty else {
            return nil
        }
        return caption
    }

    private func saveFitNotes() {
        Task {
            await store.savePortfolioFitTags(for: photo)
        }
    }

    private func deletePhoto() {
        Task {
            await store.deletePortfolioPhoto(photo)
            if !store.portfolioPhotos.contains(where: { $0.id == photo.id }) {
                dismiss()
            }
        }
    }
}

private struct GroomerPortfolioPhotoDetailSummary: View {
    let title: String
    let fitNoteSummary: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.title)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(2)

            Text(fitNoteSummary)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GroomerPortfolioPhotoArtwork: View {
    let data: Data?
    let isUnavailable: Bool
    var aspectRatio: CGFloat = 1

    var body: some View {
        let presentation = GroomerPortfolioArtworkPresentation(
            hasImageData: data != nil,
            isUnavailable: isUnavailable
        )

        BeckonModuleImage(data: data) {
            ZStack {
                Rectangle()
                    .fill(presentation.backgroundColor)

                VStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: presentation.systemImage)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(presentation.foregroundColor)

                    if let title = presentation.title {
                        Text(title)
                            .font(DesignTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(presentation.foregroundColor)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.82)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipped()
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}

struct GroomerPortfolioArtworkPresentation: Equatable {
    let title: String?
    let systemImage: String
    let isUnavailable: Bool

    init(hasImageData: Bool, isUnavailable: Bool) {
        if hasImageData {
            title = nil
            systemImage = "photo"
            self.isUnavailable = false
        } else if isUnavailable {
            title = "Photo unavailable"
            systemImage = "exclamationmark.triangle.fill"
            self.isUnavailable = true
        } else {
            title = "Loading photo"
            systemImage = "photo.on.rectangle"
            self.isUnavailable = false
        }
    }

    var accessibilityLabel: String {
        title ?? "Portfolio photo"
    }

    var foregroundColor: Color {
        isUnavailable
            ? DesignTokens.Colors.warning
            : DesignTokens.Colors.groomerAccentDark
    }

    var backgroundColor: Color {
        isUnavailable
            ? DesignTokens.Colors.warning.opacity(0.12)
            : DesignTokens.Colors.groomerAccent.opacity(0.08)
    }
}

private struct GroomerPortfolioFitNotesEditorSection: View {
    let photo: GroomerPortfolioPhoto
    @Bindable var store: GroomerProfileStore
    let presentation: GroomerPortfolioFitNotesPresentation

    var body: some View {
        BeckonSection(
            "Fit Notes",
            subtitle: "Connect this work sample to the skills it demonstrates."
        ) {
            BeckonGroupedSurface {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    if !store.canEditPortfolioTags {
                        if store.isLoadingOptionalMetadata { ProgressView("Loading fit notes...") }
                        else {
                            Text("Fit notes could not be refreshed.").font(DesignTokens.Typography.supporting)
                            Button("Retry", systemImage: "arrow.clockwise") { Task { await store.load() } }
                        }
                    }
                    if store.hasLoadedPortfolioTags {
                    Text(presentation.selectionSummary)
                        .font(DesignTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)

                    ForEach(Self.visibleGroups) { group in
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text(group.title)
                                .font(DesignTokens.Typography.caption.weight(.semibold))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)

                            LazyVGrid(
                                columns: [
                                    GridItem(
                                        .adaptive(minimum: 132),
                                        spacing: DesignTokens.Spacing.sm
                                    ),
                                ],
                                alignment: .leading,
                                spacing: DesignTokens.Spacing.sm
                            ) {
                                ForEach(signals(for: group)) { signal in
                                    GroomerPortfolioFitTagChip(
                                        signal: signal,
                                        isSelected: store.isPortfolioFitTagSelected(
                                            signal,
                                            for: photo
                                        )
                                    ) {
                                        store.togglePortfolioFitTag(signal, for: photo)
                                    }
                                    .disabled(!store.canEditPortfolioTags)
                                }
                            }
                        }
                    }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
    }

    private static var visibleGroups: [PetFitSignal.Group] {
        [.coatType, .careFlag, .serviceFit].filter { group in
            GroomerPortfolioFitTag.availableSignals.contains { $0.group == group }
        }
    }

    private func signals(for group: PetFitSignal.Group) -> [PetFitSignal] {
        GroomerPortfolioFitTag.availableSignals.filter { $0.group == group }
    }
}

private struct GroomerPortfolioFitTagChip: View {
    let signal: PetFitSignal
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(signal.title)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        isSelected
                            ? DesignTokens.Colors.groomerAccentDark
                            : DesignTokens.Colors.textTertiary
                    )
                    .accessibilityHidden(true)
            }
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .frame(minHeight: 44)
            .background(
                isSelected
                    ? DesignTokens.Colors.groomerAccent.opacity(0.14)
                    : DesignTokens.Colors.background
            )
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
                    lineWidth: 1
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(signal.title) portfolio fit tag")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct GroomerPortfolioFitNotesSaveBar: View {
    let presentation: GroomerPortfolioFitNotesPresentation
    let showDeleteConfirmation: () -> Void
    let save: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(DesignTokens.Colors.divider)

            HStack(spacing: DesignTokens.Spacing.md) {
                Button(role: .destructive, action: showDeleteConfirmation) {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(presentation.isSaveDisabled)
                .accessibilityLabel("Delete portfolio photo")
                .accessibilityIdentifier("groomer.portfolio.delete")

                Button(action: save) {
                    if presentation.saveActionTitle == "Saving..." {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ProgressView()
                                .tint(DesignTokens.Colors.surface)
                            Text(presentation.saveActionTitle)
                        }
                    } else {
                        Label(presentation.saveActionTitle, systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(BeckonPrimaryButtonStyle(accent: .groomer))
                .disabled(presentation.isSaveDisabled)
                .accessibilityIdentifier("groomer.portfolio.tags.save")
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Colors.background)
    }
}
