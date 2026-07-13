import Foundation
import SwiftUI

struct CustomerRequestDetailPresentation: Equatable {
    let showsRepublish: Bool

    init(status: GroomingRequestStatus) {
        showsRepublish = status == .cancelled
    }
}

struct CustomerRequestDetailView: View {
    let requestID: UUID
    let store: CustomerRequestsStore
    let onRepublishRequest: (CustomerGroomingRequest) -> Void

    init(
        requestID: UUID,
        store: CustomerRequestsStore,
        onRepublishRequest: @escaping (CustomerGroomingRequest) -> Void = { _ in }
    ) {
        self.requestID = requestID
        self.store = store
        self.onRepublishRequest = onRepublishRequest
    }

    var body: some View {
        if let request = store.request(withID: requestID) {
            let presentation = CustomerRequestDetailPresentation(status: request.status)
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        requestCard(request)
                        petSnapshotCard(request)
                        requestPhotosCard(request)
                        scheduleLocationCard(request)

                        if presentation.showsRepublish {
                            CustomerRequestRepublishButton(
                                actionTitle: "Create a New Request from This Template",
                                action: {
                                    onRepublishRequest(request)
                                }
                            )
                        }

                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Request Details")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("customer.requests.detail")
        } else {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                BeckonEmptyState(
                    title: "Request Unavailable",
                    message: "Refresh requests and try again.",
                    systemImage: "doc.text.magnifyingglass",
                    accent: .customer
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
            .navigationTitle("Request Details")
        }
    }

    private func requestCard(_ request: CustomerGroomingRequest) -> some View {
        BeckonAnnotatedModule(
            "Service Request",
            subtitle: "Requested service, current status, and customer notes."
        ) {
            BeckonCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                        Text(request.serviceType.title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Spacer(minLength: DesignTokens.Spacing.md)

                        BeckonStatusChip(
                            request.status.title,
                            systemImage: request.status.detailSystemImage,
                            tone: request.status.detailTone
                        )
                    }

                    if let serviceNotes = request.serviceNotes {
                        Text(serviceNotes)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func petSnapshotCard(_ request: CustomerGroomingRequest) -> some View {
        BeckonAnnotatedModule(
            "Pet Snapshot",
            subtitle: "Pet details captured when this request was published."
        ) {
            BeckonCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    DetailMetadataRow(title: "Pet", value: request.petSnapshot.name, systemImage: "heart.fill")
                    DetailMetadataRow(title: "Species", value: request.petSnapshot.species, systemImage: "tag.fill")

                    if let breed = request.petSnapshot.breed {
                        DetailMetadataRow(title: "Breed", value: breed, systemImage: "list.bullet")
                    }

                    if let size = request.petSnapshot.size {
                        DetailMetadataRow(title: "Size", value: size, systemImage: "ruler")
                    }

                    DetailMetadataRow(
                        title: "Photos",
                        value: "\(request.photoSnapshot.count)",
                        systemImage: "photo.on.rectangle"
                    )
                }
            }
        }
    }

    private func scheduleLocationCard(_ request: CustomerGroomingRequest) -> some View {
        BeckonAnnotatedModule(
            BeckonGroomingLocationModePresentation.detailSectionTitle,
            subtitle: BeckonGroomingLocationModePresentation.detailSectionSubtitle
        ) {
            BeckonCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailMetadataRow(
                    title: "Start",
                    value: GroomingRequestDateFormatting.displayString(
                        from: request.preferredStart
                    ),
                    systemImage: "clock"
                )
                DetailMetadataRow(
                    title: "End",
                    value: GroomingRequestDateFormatting.displayString(
                        from: request.preferredEnd
                    ),
                    systemImage: "clock.badge.checkmark"
                )
                DetailMetadataRow(title: "City", value: request.city, systemImage: "building.2")
                DetailMetadataRow(title: "State", value: request.state, systemImage: "map")
                DetailMetadataRow(title: "ZIP", value: request.zipCode, systemImage: "number")
                DetailMetadataRow(
                    title: BeckonGroomingLocationModePresentation.detailFieldTitle,
                    value: BeckonGroomingLocationModePresentation(
                        mode: request.locationMode,
                        perspective: .customer
                    ).title,
                    systemImage: "location.fill"
                )
                DetailMetadataRow(
                    title: "Street",
                    value: request.streetAddress,
                    systemImage: "house.fill"
                )
                if request.locationMode == .customerComesToGroomer,
                   let travelRadiusMiles = request.travelRadiusMiles {
                    DetailMetadataRow(
                        title: "Travel Radius",
                        value: "\(travelRadiusMiles) miles",
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                    )
                }
                }
            }
        }
    }

    @ViewBuilder
    private func requestPhotosCard(_ request: CustomerGroomingRequest) -> some View {
        let photos = store.requestPhotos(for: request)
        if !photos.isEmpty {
            BeckonAnnotatedModule(
                "Request Photos",
                subtitle: "\(photos.count) photo\(photos.count == 1 ? "" : "s") attached to this request."
            ) {
                BeckonCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        ForEach(photos) { photo in
                            CustomerRequestPhotoRow(
                                photo: photo,
                                data: store.requestPhotoData(for: photo)
                            )
                        }
                    }
                }
            }
        }
    }
}
struct CustomerRequestRepublishButton: View {
    let actionTitle: String
    let accessibilityIdentifier: String
    let action: () -> Void

    init(
        actionTitle: String,
        accessibilityIdentifier: String = "customer.requests.republish",
        action: @escaping () -> Void
    ) {
        self.actionTitle = actionTitle
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(actionTitle)
                .frame(maxWidth: .infinity)
            }
        .buttonStyle(BeckonSecondaryButtonStyle(accent: .customer))
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct CustomerRequestPhotoRow: View {
    let photo: GroomingRequestPhoto
    let data: Data?

    var body: some View {
        let presentation = CustomerRequestPhotoRowPresentation(
            photo: photo,
            data: data
        )

        HStack(spacing: DesignTokens.Spacing.md) {
            RequestPhotoThumbnail(
                data: data,
                accentColor: DesignTokens.Colors.customerAccent,
                systemImage: "photo"
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(presentation.title)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                if let detail = presentation.detail {
                    Text(detail)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(
                            presentation.isUnavailable
                                ? DesignTokens.Colors.warning
                                : DesignTokens.Colors.textSecondary
                        )
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

struct CustomerRequestPhotoRowPresentation: Equatable {
    let title: String
    let detail: String?
    let isUnavailable: Bool

    init(photo: GroomingRequestPhoto, data: Data?) {
        title = photo.caption ?? photo.fileName
        isUnavailable = data == nil

        if isUnavailable {
            detail = "Photo unavailable"
        } else if photo.caption != nil {
            detail = photo.fileName
        } else {
            detail = nil
        }
    }
}

private struct RequestPhotoThumbnail: View {
    let data: Data?
    let accentColor: Color
    let systemImage: String

    var body: some View {
        BeckonModuleImage(data: data) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(accentColor.opacity(0.12))
        }
        .frame(width: 58, height: 58)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
        .accessibilityHidden(true)
    }
}

struct CustomerOfferReviewSection: View {
    let request: CustomerGroomingRequest
    let store: CustomerRequestsStore

    private var offers: [CustomerOfferReview] {
        store.offers(for: request)
    }

    private var pendingOffers: [CustomerOfferReview] {
        offers.filter(\.isPending)
    }

    private var historicalOffers: [CustomerOfferReview] {
        offers.filter { !$0.isPending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            BeckonAnnotatedModule(
                "Offers",
                subtitle: "Compare pending offers and review previous offer activity."
            ) {
                Group {
                if store.isLoadingOffers(for: request), offers.isEmpty {
                    BeckonLoadingView(
                        title: "Loading Offers…",
                        message: "Checking for groomer responses.",
                        accent: .customer
                    )
                        .accessibilityIdentifier("customer.offers.loading")
                } else if offers.isEmpty,
                          let errorMessage = store.offerError(for: request) {
                    BeckonErrorBanner(
                        title: "We Could Not Load Offers",
                        message: errorMessage
                    ) {
                        Button {
                            Task {
                                await store.loadOffers(for: request)
                            }
                        } label: {
                            Label("Refresh Offers", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(BeckonSecondaryButtonStyle())
                        .disabled(store.isLoadingOffers(for: request))
                    }
                        .accessibilityIdentifier("customer.offers.error")
                } else if offers.isEmpty {
                    BeckonEmptyState(
                        title: "No Offers Yet",
                        message: "Matched groomers can submit offers while this request is open.",
                        systemImage: "tag",
                        accent: .customer
                    )
                    .accessibilityIdentifier("customer.offers.empty")
                } else {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        if !pendingOffers.isEmpty {
                            offerGroup(
                                title: "Pending Offers",
                                offers: pendingOffers,
                                isHistorical: false
                            )
                            .accessibilityIdentifier("customer.offers.pending-list")
                        } else {
                            BeckonCard {
                                Text("There are no pending offers for this request.")
                                    .font(DesignTokens.Typography.body)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if !historicalOffers.isEmpty {
                            offerGroup(
                                title: "Offer History",
                                offers: historicalOffers,
                                isHistorical: true
                            )
                            .accessibilityIdentifier("customer.offers.history-list")
                        }

                        if let errorMessage = store.offerError(for: request) {
                            BeckonErrorBanner(
                                title: "More Offers Unavailable",
                                message: errorMessage
                            )
                            .accessibilityIdentifier("customer.offers.load-more-error")
                        }

                        if store.canLoadMoreOffers(for: request)
                            || store.isLoadingMoreOffers(for: request) {
                            BeckonLoadMoreButton(
                                isLoading: store.isLoadingMoreOffers(for: request),
                                accent: .customer,
                                accessibilityIdentifier: "customer.offers.load-more"
                            ) {
                                await store.loadNextOffersPage(for: request)
                            }
                        }
                    }
                }
                }
            }

            Button {
                Task {
                    await store.loadOffers(for: request)
                }
            } label: {
                Label("Refresh Offers", systemImage: "arrow.clockwise")
            }
            .buttonStyle(BeckonSecondaryButtonStyle())
            .disabled(store.isLoadingOffers(for: request))
            .accessibilityIdentifier("customer.offers.refresh")
        }
    }

    private func offerGroup(
        title: String,
        offers: [CustomerOfferReview],
        isHistorical: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)

            LazyVStack(spacing: DesignTokens.Spacing.md) {
                ForEach(offers) { offerReview in
                    NavigationLink {
                        CustomerOfferDetailView(
                            request: request,
                            offerID: offerReview.id,
                            store: store
                        )
                    } label: {
                        CustomerOfferSummaryRow(
                            offerReview: offerReview,
                            isHistorical: isHistorical
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        AppTestOpsAccessibility.identifier(
                            prefix: "customer.offers.row",
                            serviceNotes: request.serviceNotes
                        ) ?? "customer.offers.row"
                    )
                }
            }
        }
    }
}

private struct CustomerOfferSummaryRow: View {
    let offerReview: CustomerOfferReview
    var isHistorical = false

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    BeckonProfileAvatar(
                        data: offerReview.groomerAvatarPhotoData,
                        tone: .groomer,
                        size: 52,
                        cornerRadius: 16,
                        placeholderSize: 20
                    )

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(offerReview.groomerTitle)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(offerReview.groomerLocationSummary)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }

                    Spacer(minLength: DesignTokens.Spacing.md)

                    BeckonStatusChip(
                        offerReview.offer.status.title,
                        systemImage: offerReview.offer.status.detailSystemImage,
                        tone: offerReview.offer.status.detailTone
                    )
                }

                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                    Text(offerReview.offer.priceSummary)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(isHistorical ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.textPrimary)

                    Spacer(minLength: DesignTokens.Spacing.md)

                    Text(offerReview.proposedTimeSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let fitEvidence = offerReview.fitEvidencePresentation {
                    CustomerOfferFitEvidenceBlock(
                        presentation: fitEvidence,
                        isCompact: true
                    )
                }
            }
        }
    }
}

private struct CustomerOfferFitEvidenceBlock: View {
    let presentation: CustomerOfferFitPresentation
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: "sparkles")
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.customerAccentStrong)
                .frame(
                    width: DesignTokens.Spacing.xl,
                    height: DesignTokens.Spacing.xl
                )
                .background(DesignTokens.Colors.customerAccent.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    Text("Fit Evidence")
                        .font(DesignTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.customerAccentStrong)

                    if let scoreText = presentation.scoreText {
                        Text(scoreText)
                            .font(DesignTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.customerAccentStrong)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, 3)
                            .background(DesignTokens.Colors.customerAccent.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }

                Text(presentation.listSummary)
                    .font(isCompact ? DesignTokens.Typography.caption : DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(isCompact ? 2 : nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .fill(DesignTokens.Colors.customerAccent.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .stroke(DesignTokens.Colors.customerAccent.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CustomerOfferDetailView: View {
    let request: CustomerGroomingRequest
    let offerID: UUID
    let store: CustomerRequestsStore

    private var offerReview: CustomerOfferReview? {
        store.offers(for: request).first { $0.id == offerID }
    }

    var body: some View {
        if let offerReview {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        BeckonSectionHeader(
                            "Offer",
                            subtitle: "Review the groomer proposal before accepting."
                        )

                        groomerCard(offerReview)
                        offerCard(offerReview)
                        requestCard(offerReview)
                        acceptanceCard(offerReview)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Offer")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("customer.offers.detail")
        } else {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                BeckonEmptyState(
                    title: "Offer Unavailable",
                    message: "Refresh offers and try again.",
                    systemImage: "tag.slash",
                    accent: .customer
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
            .navigationTitle("Offer")
        }
    }

    private func groomerCard(_ offerReview: CustomerOfferReview) -> some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: offerReview.groomerTitle,
                    subtitle: offerReview.groomerLocationSummary,
                    systemImage: "person.crop.circle.fill",
                    profileAvatarData: offerReview.groomerAvatarPhotoData,
                    profileAvatarTone: .groomer
                ) {
                    if offerReview.groomerProfile?.isVerified == true {
                        BeckonStatusChip(
                            "Verified",
                            systemImage: "checkmark.seal.fill",
                            tone: .success
                        )
                        .accessibilityLabel("Verified groomer")
                    }
                }

                DetailMetadataRow(
                    title: "Rating",
                    value: offerReview.ratingSummary,
                    systemImage: "star.fill"
                )

                if let fitEvidence = offerReview.fitEvidencePresentation {
                    CustomerOfferFitEvidenceBlock(
                        presentation: fitEvidence,
                        isCompact: false
                    )
                }

                if let bio = offerReview.groomerProfile?.bio {
                    Text(bio)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func offerCard(_ offerReview: CustomerOfferReview) -> some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: offerReview.offer.priceSummary,
                    subtitle: offerReview.proposedTimeSummary,
                    systemImage: "tag.fill"
                ) {
                    BeckonStatusChip(
                        offerReview.offer.status.title,
                        systemImage: offerReview.offer.status.detailSystemImage,
                        tone: offerReview.offer.status.detailTone
                    )
                }

                DetailMetadataRow(
                    title: "Start",
                    value: GroomingRequestDateFormatting.displayString(
                        from: offerReview.offer.proposedStart
                    ),
                    systemImage: "clock"
                )
                DetailMetadataRow(
                    title: "End",
                    value: GroomingRequestDateFormatting.displayString(
                        from: offerReview.offer.proposedEnd
                    ),
                    systemImage: "clock.badge.checkmark"
                )

                if let message = offerReview.offer.message {
                    Text(message)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func requestCard(_ offerReview: CustomerOfferReview) -> some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: request.petSnapshot.name,
                    subtitle: request.serviceType.title,
                    systemImage: "pawprint.fill"
                ) {
                    BeckonStatusChip(
                        request.status.title,
                        systemImage: request.status.detailSystemImage,
                        tone: request.status.detailTone
                    )
                }

                DetailMetadataRow(
                    title: "Requested Time",
                    value: requestTimeSummary,
                    systemImage: "calendar"
                )
            }
        }
    }

    private func acceptanceCard(_ offerReview: CustomerOfferReview) -> some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: "Acceptance",
                    subtitle: acceptanceMessage(for: offerReview),
                    systemImage: "checkmark.circle.fill"
                )

                if let errorMessage = store.errorMessage {
                    BeckonErrorBanner(
                        title: "We Could Not Accept This Offer",
                        message: errorMessage
                    )
                }

                if offerReview.offer.status == .pending,
                   request.status.isOpenForOffers {
                    Button {
                        Task {
                            await store.accept(
                                offerReview: offerReview,
                                for: request
                            )
                        }
                    } label: {
                        Label(
                            store.isAcceptingOffer(offerReview.offer.id) ? "Accepting…" : "Accept Offer",
                            systemImage: "checkmark.circle"
                        )
                    }
                    .buttonStyle(BeckonPrimaryButtonStyle())
                    .disabled(store.isAcceptingOffer(offerReview.offer.id))
                    .accessibilityIdentifier("customer.offers.accept")

                    Text("The backend creates the booking and conversation atomically. If the groomer becomes unavailable, no local booking is created.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    BeckonStatusChip(
                        acceptanceStatusTitle(for: offerReview),
                        systemImage: acceptanceStatusSystemImage(for: offerReview),
                        tone: acceptanceStatusTone(for: offerReview)
                    )
                }
            }
        }
    }

    private func acceptanceMessage(for offerReview: CustomerOfferReview) -> String {
        if offerReview.offer.status == .pending,
           request.status.isOpenForOffers {
            return "Accepting creates the booking and booking chat through the existing backend transaction."
        } else if offerReview.offer.status == .acceptedByCustomer {
            return "This offer has been accepted. Check the Bookings tab for the appointment."
        } else if request.status == .booked {
            return "This request is already booked."
        } else {
            return "This offer can no longer be accepted."
        }
    }

    private func acceptanceStatusTitle(for offerReview: CustomerOfferReview) -> String {
        if offerReview.offer.status == .acceptedByCustomer {
            return "Accepted"
        } else if request.status == .booked {
            return "Booked"
        } else {
            return "Unavailable"
        }
    }

    private func acceptanceStatusSystemImage(for offerReview: CustomerOfferReview) -> String {
        if offerReview.offer.status == .acceptedByCustomer || request.status == .booked {
            return "checkmark.circle.fill"
        }

        return "xmark.circle"
    }

    private func acceptanceStatusTone(for offerReview: CustomerOfferReview) -> BeckonStatusChip.Tone {
        if offerReview.offer.status == .acceptedByCustomer || request.status == .booked {
            return .success
        }

        return .neutral
    }

    private var requestTimeSummary: String {
        "\(GroomingRequestDateFormatting.displayString(from: request.preferredStart)) – \(GroomingRequestDateFormatting.displayString(from: request.preferredEnd))"
    }
}

private struct DetailCardHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let profileAvatarData: Data?
    let profileAvatarTone: BeckonDefaultProfileAvatarTone?
    private let trailing: Trailing

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        profileAvatarData: Data? = nil,
        profileAvatarTone: BeckonDefaultProfileAvatarTone? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.profileAvatarData = profileAvatarData
        self.profileAvatarTone = profileAvatarTone
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            if let profileAvatarTone {
                BeckonProfileAvatar(
                    data: profileAvatarData,
                    tone: profileAvatarTone,
                    size: DesignTokens.Spacing.xl + DesignTokens.Spacing.md,
                    cornerRadius: (DesignTokens.Spacing.xl + DesignTokens.Spacing.md) / 2,
                    placeholderSize: 18
                )
            } else {
                Image(systemName: systemImage)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.customerAccentStrong)
                    .frame(
                        width: DesignTokens.Spacing.xl + DesignTokens.Spacing.md,
                        height: DesignTokens.Spacing.xl + DesignTokens.Spacing.md
                    )
                    .background(DesignTokens.Colors.customerAccent.opacity(0.14))
                    .clipShape(DesignTokens.Shapes.circular)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .accessibilityElement(children: .combine)
    }
}

extension DetailCardHeader where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String,
        systemImage: String
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        profileAvatarData = nil
        profileAvatarTone = nil
        trailing = EmptyView()
    }
}

private struct DetailMetadataRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Label {
                Text(title)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
            } icon: {
                Image(systemName: systemImage)
                    .font(DesignTokens.Typography.caption)
            }
            .foregroundStyle(DesignTokens.Colors.textSecondary)

            Spacer(minLength: DesignTokens.Spacing.md)

            Text(value)
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

private extension GroomingRequestStatus {
    var detailTone: BeckonStatusChip.Tone {
        switch self {
        case .open, .hasOffers:
            .customer
        case .booked:
            .success
        case .cancelled, .expired, .unknown:
            .neutral
        }
    }

    var detailSystemImage: String {
        switch self {
        case .open:
            "clock"
        case .hasOffers:
            "tag"
        case .booked:
            "checkmark.circle"
        case .cancelled:
            "xmark.circle"
        case .expired:
            "hourglass"
        case .unknown:
            "questionmark.circle"
        }
    }
}

private extension GroomerOfferStatus {
    var detailTone: BeckonStatusChip.Tone {
        switch self {
        case .pending:
            .customer
        case .acceptedByCustomer:
            .success
        case .declinedByCustomer, .withdrawnByGroomer, .expired, .unknown:
            .neutral
        }
    }

    var detailSystemImage: String {
        switch self {
        case .pending:
            "clock"
        case .acceptedByCustomer:
            "checkmark.circle"
        case .declinedByCustomer:
            "xmark.circle"
        case .withdrawnByGroomer:
            "arrow.uturn.backward"
        case .expired:
            "hourglass"
        case .unknown:
            "questionmark.circle"
        }
    }
}
