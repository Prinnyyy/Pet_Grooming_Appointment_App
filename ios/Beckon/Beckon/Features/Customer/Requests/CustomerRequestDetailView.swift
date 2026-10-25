import Foundation

import SwiftUI

struct CustomerRequestDetailPresentation: Equatable {
    let showsRepublish: Bool
    let showsTimingRecovery: Bool

    init(status: GroomingRequestStatus, preferenceTimeZoneIdentifier: String? = nil) {
        showsRepublish = status == .cancelled || status == .expired
        showsTimingRecovery = status.isOpenForOffers && preferenceTimeZoneIdentifier.flatMap {
            try? GroomingServiceTiming.locationCalendar($0)
        } == nil
    }
}

// request detail in the Home style (S-002, reworked S-018/S-019): one hero (who, when, the stage path, when it closes), then
// offers, the groomers row, and last what was asked for with the way to revise it.
// Same data and actions as Features/Customer/Requests/CustomerRequestDetailView.swift (invite, revise, republish, timing recovery).
// Sheets (groomer discovery, wizard) are presented by the parent, as before.
struct CustomerRequestDetailView: View {
    let requestID: UUID
    let store: CustomerRequestsStore
    let onRepublishRequest: (CustomerGroomingRequest) -> Void
    @State private var isTimingCancellationPresented = false
    @Environment(\.dynamicTypeSize) private var typeSize

    init(
        requestID: UUID,
        store: CustomerRequestsStore,
        onRepublishRequest: ((CustomerGroomingRequest) -> Void)? = nil
    ) {
        self.requestID = requestID
        self.store = store
        self.onRepublishRequest = onRepublishRequest ?? { store.startRepublish(from: $0) }
    }

    var body: some View {
        Group {
            if let request = store.request(withID: requestID) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in content(request) }
            } else {
                DesignPage(cascades: false) {
                    BeckonLedgeNote(systemImage: "doc.text.magnifyingglass",
                        text: "This request isn't available. Refresh requests and try again.")
                }
            }
        }
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("customer.requests.detail")
    }

    private func stage(_ status: GroomingRequestStatus) -> Int? {
        switch status {
        case .open: 1
        case .hasOffers: 2
        case .booked: 3
        default: nil
        }
    }

    private func content(_ request: CustomerGroomingRequest) -> some View {
        let presentation = CustomerRequestDetailPresentation(status: request.status,
            preferenceTimeZoneIdentifier: request.preferenceTimeZoneIdentifier)
        let pending = store.offers(for: request).filter { $0.isCurrentProposal() }
        return DesignPage {
            hero(request)

            if presentation.showsRepublish {
                Button { onRepublishRequest(request) } label: {
                    DesignActionLabel(title: "Create a new request from this template", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(BeckonLedgeButtonStyle(.pill))
                .accessibilityIdentifier("customer.requests.republish")
            }

            if presentation.showsTimingRecovery {
                timingRecovery(request)
            }

            offersPreview(request, pending: request.status.isOpenForOffers ? pending : [])

            if let marketplace = store.marketplace, request.status.isOpenForOffers {
                CustomerRequestReachCard(requestID: request.id, store: marketplace.distribution) {
                    store.browseGroomers(for: request)
                }
            }

            yourRequest(request)
        }
        .task(id: requestID) {
            await store.refreshDistributionProgress(requestIDs: [requestID])
            await store.loadOffers(for: request)
        }
        .designAlertDialog(isPresented: $isTimingCancellationPresented) {
            .destructive(title: "Cancel this request?",
                message: "This closes the request and any pending offers. After cancellation succeeds, you can create a new request from its template.",
                systemImage: "xmark.circle.fill", keepTitle: "Keep Request", confirmTitle: "Cancel request",
                confirmSystemImage: "xmark.circle") { Task { await store.cancel(request) } }
        }
    }

    // MARK: Hero

    /// Who and when, where it stands, and how long it stays open: nothing else. The status is the path (or, once the request is
    /// closed, one line), so there is no separate status label; the address, pet details and notes live under "Your request".
    private func hero(_ request: CustomerGroomingRequest) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
                : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))) {
                Text(request.petSnapshot.name.prefix(1).uppercased())
                    .font(DesignTokens.Typography.Expressive.title)
                    .designIconDisc(.touch)
                    .overlay(Circle().strokeBorder(DesignTokens.Colors.customerFill, lineWidth: DesignTokens.Ledge.edgeWidth + 1))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(request.displayTitle)
                        .font(DesignTokens.Typography.Expressive.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text(request.preferredTimePresentation.summary)
                        .font(DesignTokens.Typography.Expressive.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let stage = stage(request.status) {
                BeckonJourney(stage: stage, offerCount: store.loadedCurrentOfferCount(for: request))
            } else {
                DesignInfoLine(systemImage: request.status.presentation.systemImage, text: closedMessage(request.status))
            }

            if let closes = closingLine(request) {
                BeckonMetaChip(text: closes, systemImage: "clock")
            }
        }
        .designCardBody()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(request.displayTitle). \(request.status.presentation.title).")
    }

    private func closingLine(_ request: CustomerGroomingRequest) -> String? {
        guard request.status.isOpenForOffers, let date = GroomingRequestDateFormatting.parsedDate(from: request.expiresAt),
              date > Date() else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Closes " + formatter.localizedString(for: date, relativeTo: Date())
    }

    private func closedMessage(_ status: GroomingRequestStatus) -> String {
        switch status {
        case .cancelled: "This request was cancelled. Nothing more will happen on it."
        case .expired: "This request expired before a booking was made."
        default: "This request is no longer active."
        }
    }

    // MARK: Needs attention

    private func timingRecovery(_ request: CustomerGroomingRequest) -> some View {
        DesignFactCard(spacing: DesignTokens.Spacing.md) {
            DesignBlockHeader(systemImage: "exclamationmark.triangle.fill", title: "This request can't go further")
            Text("This request has no confirmed time zone. Cancel it, then create a new request from its template and confirm the service address.")
                .designSupportingText()
            Button(role: .destructive) { isTimingCancellationPresented = true } label: {
                DesignQuietAction(title: "Cancel outdated request", systemImage: "xmark.circle", isDestructive: true)
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .disabled(store.cancellingRequestIDs.contains(request.id))
            .accessibilityIdentifier("customer.requests.timing-recovery.cancel")
        }
    }

    // MARK: Offers

    /// The offers as a row of cards you swipe through (up to five; each card is the offers page's card, trimmed), with the page dots
    /// under them and one link to compare them all. Cheapest and earliest are marked when there are several. The height stays the
    /// same whether there are two offers or twenty.
    private func offersPreview(_ request: CustomerGroomingRequest, pending: [CustomerOfferReview]) -> some View {
        let shown = Array(pending.prefix(5))
        return VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Offers", systemImage: "tag.fill", count: pending.count)
            CustomerOfferCarousel(reviews: shown, now: Date(), highlights: CustomerOfferHighlights(pending,
                isComplete: store.loadedCurrentOfferCount(for: request) != nil)) { review in
                CustomerOfferDetailView(request: request, offerID: review.id, store: store)
            }
            NavigationLink {
                CustomerRequestOffersView(requestID: request.id, store: store)
            } label: {
                DesignLinkCardLabel(
                    title: pending.count > shown.count ? "See all \(pending.count) offers"
                        : pending.count > 1 ? "Compare offers" : "Offers and history",
                    summary: pending.count > 1 ? "Sort by price or time, side by side" : "Includes past offers",
                    systemImage: "square.stack.3d.up.fill"
                )
            }
            .buttonStyle(BeckonLedgeButtonStyle(.card))
            .accessibilityIdentifier("customer.requests.see-offers")
        }
    }

    // MARK: Your request

    /// What was asked for, in one place: where, the pet's breed and size, the notes, the photos. "Revise request" is the last row
    /// of this card because it changes exactly these things (it reopens the form filled in and publishes the new version).
    private func yourRequest(_ request: CustomerGroomingRequest) -> some View {
        let pet = petDetail(request.petSnapshot)
        let notes = request.serviceNotes.flatMap { $0.isEmpty ? nil : $0 }
        return DesignSection(title: "Your request", systemImage: "doc.text.fill") {
            DesignFactRow(systemImage: "scissors", title: "Service", value: request.serviceType.title)
            DesignFactRow(systemImage: "clock", title: "Preferred time", value: request.preferredTimePresentation.summary)
            DesignFactRow(systemImage: "location.fill",
                title: BeckonGroomingLocationModePresentation(mode: request.locationMode, perspective: .customer).title,
                value: "\(request.streetAddress), \(request.city), \(request.state) \(request.zipCode)")
            if request.locationMode == .customerComesToGroomer, let miles = request.travelRadiusMiles {
                DesignFactRow(systemImage: "map", title: "Travel radius", value: "\(miles) miles")
            }
            if let pet { DesignFactRow(systemImage: "pawprint.fill", title: "Pet", value: pet) }
            if let notes { DesignFactRow(systemImage: "text.quote", title: "Notes", value: notes) }
            photos(request)
            if request.status.isOpenForOffers {
                DesignRowDivider()
                DesignManageRow(title: "Revise request", systemImage: "square.and.pencil") {
                    store.startRevision(from: request)
                }
                .disabled(store.isSubmitting || request.termsRevision == nil)
                .accessibilityHint("Reopens this request so you can change it and publish it again.")
                .accessibilityIdentifier("customer.requests.revise")
            }
        }
    }

    /// Breed (or species) and size; the name is already the title.
    private func petDetail(_ pet: GroomingRequestPetSnapshot) -> String? {
        let parts = [pet.species, pet.breed, pet.size.map { "Size \($0)" }].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func photos(_ request: CustomerGroomingRequest) -> some View {
        let photos = store.requestPhotos(for: request)
        if !photos.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(photos) { photo in
                        let presentation = CustomerRequestPhotoRowPresentation(photo: photo,
                            data: store.requestPhotoData(for: photo))
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        BeckonModuleImage(data: store.requestPhotoData(for: photo)) {
                            Image(systemName: "photo").foregroundStyle(DesignTokens.Colors.textTertiary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(DesignTokens.Colors.placeholderFill)
                        }
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.pill, style: .continuous))
                        .accessibilityHidden(true)
                        Text(presentation.title).font(DesignTokens.Typography.caption)
                            .lineLimit(2)
                        if let detail = presentation.detail {
                            Text(detail).font(DesignTokens.Typography.caption)
                                .foregroundStyle(presentation.isUnavailable
                                    ? DesignTokens.Colors.statusWarningText : DesignTokens.Colors.textSecondary)
                        }
                        }
                        .frame(width: 120, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .beckonTracksScroll()
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
