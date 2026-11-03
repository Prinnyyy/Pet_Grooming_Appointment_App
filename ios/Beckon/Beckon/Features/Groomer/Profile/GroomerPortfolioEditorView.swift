// The groomer's portfolio, in the customer prototype's language (design) and laid out from what it is for (design). Same job as
// GroomerPortfolioEditorView in Features/Groomer/Profile/GroomerPortfolioEditorView.swift: the gallery of finished work that customers
// see on the groomer's profile, and one photo's page, where the groomer says which skills the work shows (its fit notes, up to six).
// The store, the upload, the tag limit and the ids are the real ones. What the page is for: add work, and say what each photo proves,
// because a photo with no fit notes proves nothing to the matching. So the gallery is a grid of tiles built alike (the picture, its
// name, its first fit note and how many more) with the add tile first in the grid, a photo with no fit notes says so in amber, and
// one line over the grid says how many are still to do. The photo's page counts the notes (3 of 6) and stops offering more at six.
import PhotosUI
import SwiftUI


struct GroomerPortfolioEditorView: View {
    @Bindable var store: GroomerProfileStore
    @State private var selectedPhotoItem: PhotosPickerItem?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let presentation = GroomerPortfolioWorkspacePresentation(photoCount: store.portfolioPhotos.count,
            isUploading: store.isUploading, isBusy: store.isBusy)
        let photos = store.sortedPortfolioPhotos()
        let unfinished = photos.filter { store.portfolioFitTags(for: $0).isEmpty }.count

        DesignPage {
            if let status = presentation.uploadStatus {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ProgressView().tint(DesignTokens.Colors.customerDeep)
                    Text(status).designSupportingText()
                }
                .designCardBody()
                .accessibilityElement(children: .combine)
            }
            if photos.isEmpty {
                firstPhoto(disabled: presentation.isAddDisabled)
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                    BeckonLedgeHeading(title: "Work gallery", systemImage: "photo.on.rectangle", count: photos.count)
                    if unfinished > 0 {
                        DesignInfoLine(systemImage: "sparkles",
                            text: unfinished == 1 ? "1 photo has no fit notes yet" : "\(unfinished) photos have no fit notes yet")
                    }
                    LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : Self.columns,
                        alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        addTile(disabled: presentation.isAddDisabled)
                        ForEach(photos) { photo in
                            BeckonNavigationLink {
                                GroomerPortfolioPhotoView(photo: photo, store: store)
                            } label: {
                                GroomerPortfolioTile(photo: photo, store: store)
                            }
                            .buttonStyle(BeckonLedgeButtonStyle(.card))
                            .accessibilityIdentifier("groomer.portfolio.photo-card")
                        }
                    }
                }
            }
        }
        .navigationTitle("Portfolio")
        .navigationBarTitleDisplayMode(.inline)
        .beckonHidesTabBar()
        .background { GroomerProfileStatusView(store: store) }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.portfolio.edit")
    }

    /// Two columns whose cells start at the same line, whatever their words take.
    private static let columns = [
        GridItem(.flexible(), spacing: DesignTokens.Spacing.md, alignment: .top),
        GridItem(.flexible(), spacing: DesignTokens.Spacing.md, alignment: .top),
    ]

    /// The first tile of the grid: built like a photo's (a square, a name, a line), so every tile of a row is as tall as its neighbour.
    private func addTile(disabled: Bool) -> some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        DesignIconDisc(systemImage: "plus", size: .large, font: DesignTokens.Typography.Expressive.glyph)
                    }
                Text("Add work photo")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                Text("From your photos")
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
            }
            .padding(DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.dashed))
        .disabled(disabled)
        .accessibilityLabel("Add portfolio photo")
        .accessibilityIdentifier("groomer.portfolio.add")
    }

    /// No photo yet: the whole card is the way to add one, and it says why to.
    private func firstPhoto(disabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                VStack(spacing: DesignTokens.Spacing.md) {
                    DesignIconDisc(systemImage: "plus", size: .large, font: DesignTokens.Typography.Expressive.glyph)
                    Text("Add your first work photo")
                        .font(DesignTokens.Typography.Expressive.title)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .multilineTextAlignment(.center)
                    Text("Add finished grooming work to give customers a clear view of your style.")
                        .font(DesignTokens.Typography.Expressive.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DesignTokens.Spacing.xl)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.dashed))
            .disabled(disabled)
            .accessibilityLabel("Add portfolio photo")
            .accessibilityIdentifier("groomer.portfolio.add")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.portfolio.empty")
    }

    private func upload(_ item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            store.errorMessage = "We could not read that photo."
            store.actionErrorMessage = store.errorMessage
            return
        }
        let contentType = item.supportedContentTypes.lazy.compactMap(GroomerPortfolioPhotoContentType.init(uniformType:)).first ?? .jpeg
        await store.uploadPortfolioPhoto(data: data, contentType: contentType)
    }
}


/// A photo of the gallery: the picture, what it is called, and its first fit note with how many more there are; or, when it has none,
/// the one thing to do about it. Two lines under the picture, always, so the tiles of a row are as tall as each other.
private struct GroomerPortfolioTile: View {
    let photo: GroomerPortfolioPhoto
    @Bindable var store: GroomerProfileStore
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            GroomerPortfolioArtwork(data: store.portfolioPhotoData(for: photo), isUnavailable: store.isPortfolioPhotoDataUnavailable(photo))
            Text(caption ?? "Work photo")
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
            notes
        }
        .padding(DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var notes: some View {
        let tags = store.portfolioFitTags(for: photo)
        if let first = tags.first {
            // The count of the others is its own piece, so a long first note is cut and the count never is.
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(first.signal.title)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                if tags.count > 1 {
                    Text("+\(tags.count - 1)")
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .fixedSize()
                        .accessibilityLabel("\(tags.count - 1) more")
                }
            }
            .font(DesignTokens.Typography.Expressive.chip)
        } else {
            Label("Add fit notes", systemImage: "sparkles")
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.statusWarningText)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
        }
    }

    private var caption: String? {
        guard let value = photo.caption?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}


/// The picture, or what stands in for it while it loads or when it could not.
private struct GroomerPortfolioArtwork: View {
    let data: Data?
    let isUnavailable: Bool
    var aspectRatio: CGFloat = 1

    var body: some View {
        let presentation = GroomerPortfolioArtworkPresentation(hasImageData: data != nil, isUnavailable: isUnavailable)
        BeckonModuleImage(data: data) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: presentation.systemImage)
                    .font(DesignTokens.Typography.Expressive.glyph)
                if let title = presentation.title {
                    Text(title)
                        .font(DesignTokens.Typography.Expressive.chip)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                }
            }
            .foregroundStyle(presentation.isUnavailable ? DesignTokens.Colors.statusWarningText : DesignTokens.Colors.customerDeep)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(presentation.isUnavailable ? DesignTokens.Colors.surface : DesignTokens.Colors.customerTint)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.inset, style: .continuous))
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}


// MARK: One photo

/// One photo's page: the picture and its name, then what it shows (fit notes, up to six, counted), with Save beside Delete.
struct GroomerPortfolioPhotoView: View {
    let photo: GroomerPortfolioPhoto
    @Bindable var store: GroomerProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false

    var body: some View {
        let chosen = store.selectedPortfolioFitTagIDsByPhotoID[photo.id]?.count ?? 0
        let presentation = GroomerPortfolioFitNotesPresentation(
            selectedTagCount: chosen,
            maximumTagCount: GroomerPortfolioFitTag.maximumTagsPerPhoto,
            isSaving: store.isSaving,
            isBusy: store.isBusy || !store.canEditPortfolioTags
        )

        DesignPage {
            GroomerPortfolioArtwork(data: store.portfolioPhotoData(for: photo),
                isUnavailable: store.isPortfolioPhotoDataUnavailable(photo), aspectRatio: 4 / 3)
                .accessibilityIdentifier("groomer.portfolio.photo-artwork")
            Text(caption ?? "Work photo")
                .font(DesignTokens.Typography.Expressive.section)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            fitNotes(chosen: chosen)
            GroomerBarClearance()
        }
        .navigationTitle("Portfolio photo")
        .navigationBarTitleDisplayMode(.inline)
        .beckonHidesTabBar()
        .background { GroomerProfileStatusView(store: store) }
        .beckonStationaryPageAction {
            GroomerSaveBar(title: "Save fit notes", isSaving: store.isSaving, isDisabled: presentation.isSaveDisabled,
                identifier: "groomer.portfolio.tags.save", leading: {
                    Button { isConfirmingDelete = true } label: {
                        Image(systemName: "trash")
                            .font(DesignTokens.Typography.Expressive.glyph)
                            .foregroundStyle(DesignTokens.Colors.statusErrorText)
                            .frame(width: DesignTokens.Metrics.ledgePrimaryButtonHeight, height: DesignTokens.Metrics.ledgePrimaryButtonHeight)
                            .beckonLedge(.round)
                    }
                    .buttonStyle(BeckonGuardedPlainButtonStyle())
                    .disabled(presentation.isSaveDisabled)
                    .accessibilityLabel("Delete portfolio photo")
                    .accessibilityIdentifier("groomer.portfolio.delete")
                }) {
                Task { await store.savePortfolioFitTags(for: photo) }
            }
        }
        .designAlertDialog(isPresented: $isConfirmingDelete) {
            .destructive(title: "Delete this portfolio photo?", message: "This removes the photo and its fit notes from your portfolio.",
                systemImage: "trash.fill", keepTitle: "Keep it", confirmTitle: "Delete photo", confirmSystemImage: "trash",
                confirmIdentifier: "groomer.portfolio.delete.confirm") {
                Task {
                    await store.deletePortfolioPhoto(photo)
                    if !store.portfolioPhotos.contains(where: { $0.id == photo.id }) { dismiss() }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.portfolio.detail")
    }

    private var caption: String? {
        guard let value = photo.caption?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    /// What the photo shows. Six is all a photo can say: at six the skills left over are dimmed, and the heading says "6 of 6".
    private func fitNotes(chosen: Int) -> some View {
        let isFull = chosen >= GroomerPortfolioFitTag.maximumTagsPerPhoto
        return VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Fit notes", systemImage: "sparkles",
                detail: "\(chosen) of \(GroomerPortfolioFitTag.maximumTagsPerPhoto)")
            Text("Connect this work sample to the skills it demonstrates.").designSupportingText()
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                if !store.hasLoadedPortfolioTags || (!store.isLoadingOptionalMetadata && !store.canEditPortfolioTags) {
                    if store.isLoadingOptionalMetadata {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            ProgressView().tint(DesignTokens.Colors.customerDeep)
                            Text("Loading fit notes…").designSupportingText()
                        }
                    } else {
                        DesignInfoLine(systemImage: "exclamationmark.triangle.fill", text: "Fit notes could not be refreshed.")
                        Button { Task { await store.load() } } label: {
                            DesignQuietAction(title: "Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(BeckonGuardedPlainButtonStyle())
                    }
                }
                if store.hasLoadedPortfolioTags {
                    ForEach(Self.groups) { group in
                        GroomerCaptioned(title: group.beckonTitle) {
                            BeckonFlowLayout(spacing: DesignTokens.Spacing.sm, rowSpacing: DesignTokens.Spacing.sm) {
                                ForEach(GroomerPortfolioFitTag.availableSignals.filter { $0.group == group }) { signal in
                                    let isSelected = store.isPortfolioFitTagSelected(signal, for: photo)
                                    DesignChoiceChip(title: signal.title, isSelected: isSelected) {
                                        store.togglePortfolioFitTag(signal, for: photo)
                                    }
                                    .disabled(!store.canEditPortfolioTags || (isFull && !isSelected))
                                    .accessibilityLabel("\(signal.title) portfolio fit tag")
                                }
                            }
                        }
                    }
                }
            }
            .designCardBody()
        }
    }

    private static var groups: [PetFitSignal.Group] {
        [.coatType, .careFlag, .serviceFit].filter { group in
            GroomerPortfolioFitTag.availableSignals.contains { $0.group == group }
        }
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
            ? DesignTokens.Colors.statusWarningText
            : DesignTokens.Colors.groomerInk
    }

    var backgroundColor: Color {
        isUnavailable
            ? DesignTokens.Colors.surface
            : DesignTokens.Colors.groomerTint
    }
}

private struct GroomerPortfolioFitNotesEditorSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let photo: GroomerPortfolioPhoto
    @Bindable var store: GroomerProfileStore
    let presentation: GroomerPortfolioFitNotesPresentation

    var body: some View {
        BeckonSection(
            "Fit notes",
            subtitle: "Connect this work sample to the skills it demonstrates."
        ) {
            BeckonGroupedSurface {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    if !store.hasLoadedPortfolioTags || (!store.isLoadingOptionalMetadata && !store.canEditPortfolioTags) {
                        if store.isLoadingOptionalMetadata { ProgressView("Loading fit notes...") }
                        else {
                            Text("Fit notes could not be refreshed.").font(DesignTokens.Typography.supporting)
                            Button("Retry", systemImage: "arrow.clockwise") { Task { await store.load() } }
                                .buttonStyle(BeckonGuardedPlainButtonStyle())
                        }
                    }
                    if store.hasLoadedPortfolioTags {
                    Text(presentation.selectionSummary)
                        .font(DesignTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.groomerInk)

                    ForEach(Self.visibleGroups) { group in
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text(group.title)
                                .font(DesignTokens.Typography.caption.weight(.semibold))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)

                            LazyVGrid(
                                columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [
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
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        isSelected
                            ? DesignTokens.Colors.groomerInk
                            : DesignTokens.Colors.textTertiary
                    )
                    .accessibilityHidden(true)
            }
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .frame(minHeight: 44)
            .background(
                isSelected
                    ? DesignTokens.Colors.groomerTint
                    : DesignTokens.Colors.appBackground
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
                        ? DesignTokens.Colors.groomerDeep
                        : DesignTokens.Colors.borderSoft,
                    lineWidth: 1
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
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
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .disabled(presentation.isSaveDisabled)
                .accessibilityLabel("Delete portfolio photo")
                .accessibilityIdentifier("groomer.portfolio.delete")

                Button(action: save) {
                    if presentation.saveActionTitle == "Saving..." {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ProgressView()
                                .tint(DesignTokens.Colors.groomerInk)
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
        .background(DesignTokens.Colors.appBackground)
    }
}
