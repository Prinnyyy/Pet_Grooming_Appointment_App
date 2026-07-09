import PhotosUI
import SwiftUI

struct GroomerPortfolioEditorView: View {
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

private struct GroomerPortfolioSection: View {
    @Bindable var store: GroomerProfileStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader(
                "Portfolio",
                subtitle: "Finished work and fit notes for customers reviewing your profile."
            )

            GroomerPortfolioOverviewCard(
                summary: store.portfolioOverviewSummary
            ) {
                addPhotoPicker(isFullWidth: false)
            }

            if store.isUploading {
                GroomerPortfolioUpdatingCard()
            }

            if store.portfolioPhotos.isEmpty {
                GroomlyEmptyState(
                    title: "No Work Photos",
                    message: "Add finished grooming photos that show your coat work and handling style.",
                    systemImage: "photo.on.rectangle",
                    accent: .groomer
                ) {
                    addPhotoPicker(isFullWidth: true)
                }
                .accessibilityIdentifier("groomer.portfolio.empty")
            } else {
                LazyVGrid(
                    columns: Self.photoGridColumns,
                    alignment: .leading,
                    spacing: DesignTokens.Spacing.md
                ) {
                    ForEach(store.sortedPortfolioPhotos()) { photo in
                        GroomerPortfolioPhotoCard(
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

    private static let photoGridColumns = [
        GridItem(.flexible(), spacing: DesignTokens.Spacing.md),
        GridItem(.flexible(), spacing: DesignTokens.Spacing.md),
    ]
}

private struct GroomerPortfolioOverviewCard<AddButton: View>: View {
    let summary: String
    let addButton: AddButton

    init(
        summary: String,
        @ViewBuilder addButton: () -> AddButton
    ) {
        self.summary = summary
        self.addButton = addButton()
    }

    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.md) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(DesignTokens.Typography.headline.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .frame(width: 44, height: 44)
                    .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                    .clipShape(DesignTokens.Shapes.circular)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Work Gallery")
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text(summary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                addButton
                    .layoutPriority(1)
            }
            .accessibilityElement(children: .contain)
        }
    }
}

private struct GroomerPortfolioUpdatingCard: View {
    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ProgressView()
                    .tint(DesignTokens.Colors.groomerAccent)

                Text("Updating portfolio…")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct GroomerPortfolioPhotoCard: View {
    let photo: GroomerPortfolioPhoto
    @Bindable var store: GroomerProfileStore

    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.xs) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ZStack(alignment: .topTrailing) {
                    let data = store.portfolioPhotoData(for: photo)
                    GroomerPortfolioPhotoArtwork(
                        data: data,
                        isUnavailable: store.isPortfolioPhotoDataUnavailable(photo)
                    )

                    Button(role: .destructive) {
                        Task {
                            await store.deletePortfolioPhoto(photo)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32)
                    }
                    .foregroundStyle(DesignTokens.Colors.error)
                    .background(DesignTokens.Colors.surface.opacity(0.94))
                    .overlay {
                        DesignTokens.Shapes.circular
                            .stroke(DesignTokens.Colors.error.opacity(0.26), lineWidth: 1)
                    }
                    .clipShape(DesignTokens.Shapes.circular)
                    .disabled(store.isBusy)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete portfolio photo")
                    .padding(DesignTokens.Spacing.xs)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(captionText ?? "Work Photo")
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(store.portfolioFitTagSummary(for: photo))
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    GroomerPortfolioFitTagsSection(
                        photo: photo,
                        store: store
                    )
                    .padding(.top, DesignTokens.Spacing.xs)
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.bottom, DesignTokens.Spacing.sm)
            }
        }
        .accessibilityIdentifier("groomer.portfolio.photo-card")
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

private struct GroomerPortfolioPhotoArtwork: View {
    let data: Data?
    let isUnavailable: Bool

    var body: some View {
        let presentation = GroomerPortfolioArtworkPresentation(
            hasImageData: data != nil,
            isUnavailable: isUnavailable
        )

        GroomlyModuleImage(data: data) {
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
        .aspectRatio(1, contentMode: .fit)
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

private struct GroomerPortfolioFitTagsSection: View {
    let photo: GroomerPortfolioPhoto
    @Bindable var store: GroomerProfileStore
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                ForEach(Self.visibleGroups) { group in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text(group.title)
                            .font(DesignTokens.Typography.caption.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .textCase(.uppercase)

                        LazyVGrid(
                            columns: [
                                GridItem(
                                    .adaptive(minimum: 112),
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
                            }
                        }
                    }
                }

                Button {
                    Task {
                        await store.savePortfolioFitTags(for: photo)
                    }
                } label: {
                    Label("Save Fit Notes", systemImage: "checkmark")
                }
                .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer, isFullWidth: true))
                .disabled(store.isBusy)
                .accessibilityIdentifier("groomer.portfolio.tags.save")
            }
            .padding(.top, DesignTokens.Spacing.sm)
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("Fit notes")
                    .font(DesignTokens.Typography.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(selectedCount)/\(GroomerPortfolioFitTag.maximumTagsPerPhoto)")
                    .font(DesignTokens.Typography.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(DesignTokens.Colors.groomerAccent.opacity(0.12))
                    .clipShape(DesignTokens.Shapes.chip)
            }
            .accessibilityElement(children: .combine)
        }
        .tint(DesignTokens.Colors.groomerAccent)
    }

    private var selectedCount: Int {
        store.selectedPortfolioFitTagIDsByPhotoID[photo.id]?.count ?? 0
    }

    private static var visibleGroups: [PetFitSignal.Group] {
        [.coatType, .careFlag, .serviceFit].filter { group in
            GroomerPortfolioFitTag.availableSignals.contains(where: {
                $0.group == group
            })
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
                    .font(.system(size: 14, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(
                isSelected
                    ? DesignTokens.Colors.surface
                    : DesignTokens.Colors.textPrimary
            )
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .frame(minHeight: 38)
            .background(
                isSelected
                    ? DesignTokens.Colors.groomerAccent
                    : DesignTokens.Colors.background
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected
                            ? DesignTokens.Colors.groomerAccent
                            : DesignTokens.Colors.borderSoft,
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(signal.title) portfolio fit tag")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
