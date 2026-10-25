import Foundation

import SwiftUI

enum CustomerRequestCollectionState: Equatable {
    case loading
    case empty
    case error(String)
    case loaded
}

struct CustomerRequestsDashboardPresentation: Equatable {
    let activeCardCount: Int
    let closedRequestCount: Int
    let photoRetryCount: Int
    let isLoading: Bool
    let loadErrorMessage: String?

    var state: CustomerRequestCollectionState {
        if activeCardCount > 0 || closedRequestCount > 0 || photoRetryCount > 0 {
            return .loaded
        }
        if isLoading {
            return .loading
        }
        if let message = loadErrorMessage?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !message.isEmpty {
            return .error(message)
        }
        return .empty
    }
}

struct CustomerRequestsHeader: View {
    static let title = "Requests"
    static let createActionTitle = "New Request"

    let cardCount: Int
    let isCreateDisabled: Bool
    let createRequest: () -> Void

    var body: some View {
        // Same shape as the Home header: the title with one line under it, the action on the right. The count is words in that
        // line, never a badge next to the title, so nothing pushes the button to another row whatever the count is.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                titleBlock
                    .frame(maxWidth: .infinity, alignment: .leading)
                createButton
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                titleBlock
                createButton
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(Self.title)
                .font(DesignTokens.Typography.Expressive.display)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(summaryLine)
                .designSupportingText()
        }
    }

    private var summaryLine: String {
        switch cardCount {
        case 0: isCreateDisabled ? "Add a pet profile to get started" : "Ask groomers for offers"
        case 1: "1 active request"
        default: "\(cardCount) active requests"
        }
    }

    private var createButton: some View {
        Button(action: createRequest) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "plus").font(DesignTokens.Typography.Expressive.glyph)
                Text(Self.createActionTitle).font(DesignTokens.Typography.Expressive.emphasis)
            }
            .foregroundStyle(DesignTokens.Colors.customerInk)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.pill))
        .disabled(isCreateDisabled)
        .accessibilityIdentifier("customer.requests.create")
        .accessibilityHint(
            isCreateDisabled
                ? "Add a pet profile before creating a request."
                : "Opens the grooming request form."
        )
    }
}

struct CustomerRequestLoadFailureBanner: View {
    let message: String
    var accessibilityIdentifier = "customer.requests.load-error"
    let retry: () -> Void

    var body: some View {
        BeckonErrorBanner(
            title: "Requests didn't load",
            message: message,
            systemImage: "arrow.clockwise.circle"
        ) {
            Button(action: retry) {
                Text("Try again")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.card))
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct CustomerRequestCarouselPosition: Equatable {
    let current: Int
    let total: Int

    init(requestIDs: [UUID], visibleRequestID: UUID?) {
        total = requestIDs.count
        let resolvedID = visibleRequestID.flatMap { requestID in
            requestIDs.contains(requestID) ? requestID : nil
        } ?? requestIDs.first
        current = resolvedID
            .flatMap { requestIDs.firstIndex(of: $0) }
            .map { $0 + 1 } ?? 0
    }

    var label: String {
        "Request \(current) of \(total)"
    }

    var displayText: String {
        "\(current) of \(total)"
    }
}

struct CustomerRequestCarouselPositionIndicator: View {
    let position: CustomerRequestCarouselPosition

    var body: some View {
        Text(position.displayText)
            .font(DesignTokens.Typography.Expressive.chip)
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel(position.label)
            .accessibilityIdentifier("customer.requests.carousel-position")
    }
}

struct CustomerRequestPhotoUploadRetryPresentation: Equatable {
    let title: String
    let message: String
    let retryTitle = "Retry Upload"
    let discardTitle = "Remove Photos"

    init(photoCount: Int) {
        let count = max(1, photoCount)
        if count == 1 {
            title = "1 request photo needs uploading"
            message = "The request was published, but this photo was not uploaded."
        } else {
            title = "\(count) request photos need uploading"
            message = "The request was published, but these photos were not uploaded."
        }
    }
}

struct CustomerRequestPhotoUploadRetryBanner: View {
    let retry: CustomerRequestPhotoUploadRetry
    let isRetrying: Bool
    let retryAction: () -> Void
    let discardAction: () -> Void

    var body: some View {
        let presentation = CustomerRequestPhotoUploadRetryPresentation(
            photoCount: retry.photos.count
        )
        BeckonErrorBanner(
            title: presentation.title,
            message: presentation.message,
            systemImage: "photo.badge.exclamationmark"
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    actions(presentation: presentation)
                }

                VStack(spacing: DesignTokens.Spacing.sm) {
                    actions(presentation: presentation)
                }
            }
        }
        .accessibilityIdentifier(
            "customer.requests.photo-retry.\(retry.requestID.uuidString)"
        )
    }

    @ViewBuilder
    private func actions(
        presentation: CustomerRequestPhotoUploadRetryPresentation
    ) -> some View {
        Button(action: retryAction) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isRetrying {
                    ProgressView().tint(DesignTokens.Colors.customerInk)
                    Text("Uploading...")
                } else {
                    Image(systemName: "arrow.clockwise")
                    Text(presentation.retryTitle)
                }
            }
            .font(DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(DesignTokens.Colors.customerInk)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.pill))
        .disabled(isRetrying)

        Button(role: .destructive, action: discardAction) {
            DesignQuietAction(title: presentation.discardTitle, systemImage: "trash", isDestructive: true)
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
        .disabled(isRetrying)
    }
}

struct CustomerRequestPhotoUploadRetryList: View {
    let store: CustomerRequestsStore

    var body: some View {
        ForEach(store.requestPhotoUploadRetries) { retry in
            CustomerRequestPhotoUploadRetryBanner(
                retry: retry,
                isRetrying: store.isRetryingRequestPhotos(
                    for: retry.requestID
                ),
                retryAction: {
                    Task {
                        await store.retryRequestPhotos(
                            for: retry.requestID
                        )
                    }
                },
                discardAction: {
                    store.discardRequestPhotoUploadRetry(
                        for: retry.requestID
                    )
                }
            )
        }
    }
}

struct CustomerRequestCardCarousel: View {
    let cards: [CustomerRequestActionCardItem]
    let store: CustomerRequestsStore
    @Binding var focusedRequestID: UUID?
    let onViewBooking: (CustomerRequestBookingHandoff) -> Void
    let onCancelRequest: (CustomerGroomingRequest) -> Void
    @State private var visibleRequestID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    ForEach(cards) { card in
                        CustomerRequestCard(
                            card: card,
                            store: store,
                            onViewBooking: onViewBooking,
                            onCancelRequest: onCancelRequest
                        )
                        .containerRelativeFrame(.horizontal) { length, _ in
                            length
                        }
                        .id(card.request.id)
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, DesignTokens.Spacing.screenHorizontal, for: .scrollContent)
            // Horizontal paging intentionally cancels page inset so each card aligns to the viewport.
            .padding(.horizontal, -DesignTokens.Spacing.screenHorizontal)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $visibleRequestID)
            .onAppear {
                synchronizeVisibleRequest(animated: false)
            }
            .onChange(of: focusedRequestID) { _, _ in
                synchronizeVisibleRequest(animated: true)
            }
            .onChange(of: requestIDs) { _, _ in
                synchronizeVisibleRequest(animated: false)
            }

            if cardCount > 1 {
                CustomerRequestCarouselPositionIndicator(position: position)
            }
        }
    }

    private var cardCount: Int {
        cards.count
    }

    private var requestIDs: [UUID] {
        cards.map(\.request.id)
    }

    private var position: CustomerRequestCarouselPosition {
        CustomerRequestCarouselPosition(
            requestIDs: requestIDs,
            visibleRequestID: visibleRequestID
        )
    }

    private func synchronizeVisibleRequest(animated: Bool) {
        let target: UUID?
        if let focusedRequestID, requestIDs.contains(focusedRequestID) {
            target = focusedRequestID
            self.focusedRequestID = nil
        } else if let visibleRequestID, requestIDs.contains(visibleRequestID) {
            target = visibleRequestID
        } else {
            target = requestIDs.first
        }

        if animated {
            withAnimation(.smooth(duration: 0.35)) {
                visibleRequestID = target
            }
        } else {
            visibleRequestID = target
        }
    }
}

struct CustomerRequestSummaryCarousel: View {
    let cards: [CustomerRequestActionCardItem]
    let onSelectRequest: (UUID) -> Void
    @State private var visibleRequestID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    ForEach(cards) { card in
                        Button {
                            onSelectRequest(card.request.id)
                        } label: {
                            CustomerRequestSummaryCard(card: card)
                        }
                        .buttonStyle(BeckonLedgeButtonStyle(.card))
                        .beckonCarouselTilt()
                            .containerRelativeFrame(.horizontal) { length, _ in
                                length
                            }
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, DesignTokens.Spacing.screenHorizontal, for: .scrollContent)
            // Horizontal paging intentionally cancels page inset so each card aligns to the viewport.
            .padding(.horizontal, -DesignTokens.Spacing.screenHorizontal)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $visibleRequestID)
            .beckonTracksScroll()
            .onAppear {
                synchronizeVisibleRequest()
            }
            .onChange(of: requestIDs) { _, _ in
                synchronizeVisibleRequest()
            }

            if cards.count > 1 {
                CustomerRequestCarouselPositionIndicator(position: position)
            }
        }
    }

    private var requestIDs: [UUID] {
        cards.map(\.request.id)
    }

    private var position: CustomerRequestCarouselPosition {
        CustomerRequestCarouselPosition(
            requestIDs: requestIDs,
            visibleRequestID: visibleRequestID
        )
    }

    private func synchronizeVisibleRequest() {
        if let visibleRequestID, requestIDs.contains(visibleRequestID) {
            return
        }
        visibleRequestID = requestIDs.first
    }
}

struct CustomerRequestSummaryCard: View {
    let card: CustomerRequestActionCardItem
    @Environment(\.dynamicTypeSize) private var typeSize

    private var presentation: CustomerRequestSummaryPresentation {
        CustomerRequestSummaryPresentation(card: card)
    }

    // The carousel's ledge button style draws the card surface; this view is its content.
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            headerLayout {
                BeckonModuleImage(data: card.petAvatarPhotoData) {
                    Text(presentation.initial)
                        .font(DesignTokens.Typography.Expressive.title)
                        .dynamicTypeSize(.large)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DesignTokens.Colors.customerTint)
                }
                .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: DesignTokens.Metrics.minimumTouchTarget)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(DesignTokens.Colors.customerFill, lineWidth: DesignTokens.Ledge.edgeWidth + 1))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(presentation.title)
                        .font(DesignTokens.Typography.Expressive.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text(presentation.time.summary)
                        .font(DesignTokens.Typography.Expressive.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let step = presentation.step {
                BeckonJourney(stage: step, offerCount: card.loadedOfferCount)
            }

            footerLayout {
                BeckonStatusChip(presentation.status)
                if !typeSize.isAccessibilitySize { Spacer(minLength: DesignTokens.Spacing.sm) }
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text("Review")
                    Image(systemName: "chevron.right")
                }
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                .beckonLedge(.pill)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityIdentifier("customer.requests.progress-card.summary")
    }

    private var headerLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))
    }

    private var footerLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))
    }
}

private struct CustomerRequestCard: View {
    let card: CustomerRequestActionCardItem
    let store: CustomerRequestsStore
    let onViewBooking: (CustomerRequestBookingHandoff) -> Void
    let onCancelRequest: (CustomerGroomingRequest) -> Void

    var body: some View {
        summary
    }

    @ViewBuilder
    private var summary: some View {
        let content = VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            CustomerRequestBriefHeader(
                request: request,
                petAvatarPhotoData: card.petAvatarPhotoData,
                presentation: presentation
            )
            .accessibilityIdentifier(
                AppTestOpsAccessibility.identifier(prefix: "customer.requests.row", serviceNotes: request.serviceNotes)
                    ?? (isBookingHandoff ? "customer.requests.booking-handoff" : "customer.requests.progress-card")
            )
            .accessibilityValue(AppTestOpsAccessibility.requestReference(request.id))

            if handoff == nil, let step = CustomerRequestSummaryPresentation(card: card).step {
                BeckonJourney(stage: step, offerCount: card.loadedOfferCount)
            }

            if handoff == nil, request.status.isOpenForOffers, let marketplace = store.marketplace {
                reach(marketplace.distribution)
            }

            if let handoff {
                CustomerRequestBookingHandoffAction(handoff: handoff, onViewBooking: onViewBooking)
            } else {
                CustomerRequestCardActions(request: request, store: store, onCancelRequest: onCancelRequest)
            }
        }
        if isBookingHandoff {
            content.designBanner()
        } else {
            content
                .designCardBody()
        }
    }

    /// Who has heard about the request, between the journey and the buttons; one tap opens the groomers sheet to invite more.
    private func reach(_ distribution: CustomerRequestDistributionStore) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Divider()
            Button { store.browseGroomers(for: request) } label: {
                CustomerRequestReachRow(requestID: request.id, store: distribution)
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityHint("Invite more groomers or see who has this request.")
            .accessibilityIdentifier("customer.requests.invite")
            Divider()
        }
    }

    private var isBookingHandoff: Bool { handoff != nil }
    private var request: CustomerGroomingRequest { card.request }
    private var handoff: CustomerRequestBookingHandoff? { card.handoff }

    private var presentation: CustomerRequestCardPresentation {
        CustomerRequestCardPresentation(request: request, handoff: handoff)
    }
}

struct CustomerRequestCardPresentation {
    struct InfoLine: Equatable {
        let systemImage: String
        let text: String
    }

    let headline: String
    let subtitle: String
    let statusPresentation: BeckonStatusPresentation
    let infoLines: [InfoLine]
    let isConfirmedHandoff: Bool

    init(
        request: CustomerGroomingRequest,
        handoff: CustomerRequestBookingHandoff?
    ) {
        isConfirmedHandoff = handoff != nil

        if let handoff {
            headline = "Booking\nconfirmed"
            subtitle = request.title
            statusPresentation = handoff.booking.status.presentation
            infoLines = [
                InfoLine(
                    systemImage: "calendar",
                    text: handoff.booking.scheduledTimeSummary
                ),
                InfoLine(
                    systemImage: "mappin.and.ellipse",
                    text: request.compactLocationSummary
                ),
            ]
        } else {
            headline = request.progressCardHeadline
            subtitle = request.title
            statusPresentation = request.status.presentation
            infoLines = [
                InfoLine(
                    systemImage: "calendar",
                    text: request.preferredTimePresentation.summary
                ),
                InfoLine(
                    systemImage: "mappin.and.ellipse",
                    text: request.compactLocationSummary
                ),
            ]
        }
    }

}

private struct CustomerRequestBookingHandoffAction: View {
    let handoff: CustomerRequestBookingHandoff
    let onViewBooking: (CustomerRequestBookingHandoff) -> Void

    var body: some View {
        Button {
            onViewBooking(handoff)
        } label: {
            DesignActionLabel(title: "View booking", systemImage: "arrow.right")
        }
        .buttonStyle(BeckonLedgeButtonStyle(.pill))
        .accessibilityLabel("View booking")
        .accessibilityIdentifier("customer.requests.booking-handoff.view-booking")
    }
}

private struct CustomerRequestBriefHeader: View {
    let request: CustomerGroomingRequest
    let petAvatarPhotoData: Data?
    let presentation: CustomerRequestCardPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    requestIdentity
                    statusChip
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    requestIdentity
                    statusChip
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ForEach(Array(presentation.infoLines.enumerated()), id: \.offset) { _, infoLine in
                    CustomerRequestBriefInfoLine(systemImage: infoLine.systemImage, text: infoLine.text)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var requestIdentity: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            BeckonPetAvatar(
                data: petAvatarPhotoData,
                systemImage: BeckonPetPresentation.symbol(for: request.petSnapshot.species),
                width: 56,
                height: 56,
                cornerRadius: 28
            )
            .overlay(Circle().strokeBorder(DesignTokens.Colors.customerFill, lineWidth: DesignTokens.Ledge.edgeWidth + 1))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(presentation.headline.replacingOccurrences(of: "\n", with: " "))
                    .font(DesignTokens.Typography.Expressive.title)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(presentation.subtitle)
                    .designSupportingText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusChip: some View {
        BeckonStatusChip(presentation.statusPresentation)
    }
}

private struct CustomerRequestBriefInfoLine: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.Expressive.label)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .frame(width: 22)
                .accessibilityHidden(true)

            Text(text)
                .designSupportingText()
        }
    }
}

/// One primary and two quiet actions: "Compare offers" is the only filled button; "Details" and "Cancel request" share one row of
/// text actions under it, so the three never compete (and the card does not end in a stack of three different buttons).
private struct CustomerRequestCardActions: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let request: CustomerGroomingRequest
    let store: CustomerRequestsStore
    let onCancelRequest: (CustomerGroomingRequest) -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            offersLink
            quietActions
        }
    }

    private var presentation: CustomerRequestCardActionsPresentation {
        CustomerRequestCardActionsPresentation(status: request.status)
    }

    private var quietActions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))
        return layout {
            detailLink
            if !dynamicTypeSize.isAccessibilitySize {
                Rectangle()
                    .fill(DesignTokens.Colors.divider)
                    .frame(width: 1, height: DesignTokens.Metrics.ledgeIconTile)
                    .accessibilityHidden(true)
            }
            cancelButton
        }
    }

    private var detailLink: some View {
        NavigationLink {
            CustomerRequestDetailView(requestID: request.id, store: store)
        } label: {
            DesignQuietAction(title: "Details", systemImage: "doc.text.magnifyingglass")
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
        .accessibilityLabel("Request detail")
        .accessibilityIdentifier(
            AppTestOpsAccessibility.identifier(prefix: "customer.requests.detail", serviceNotes: request.serviceNotes)
                ?? "customer.requests.detail"
        )
        .accessibilityValue(AppTestOpsAccessibility.requestReference(request.id))
    }

    private var offersLink: some View {
        NavigationLink {
            CustomerRequestOffersView(requestID: request.id, store: store)
        } label: {
            DesignActionLabel(title: "Compare offers", systemImage: "tag.fill")
        }
        .buttonStyle(BeckonLedgeButtonStyle(.pill))
        .disabled(!presentation.isOffersEnabled)
        .accessibilityLabel("Request offers")
        .accessibilityIdentifier("customer.requests.offers")
        .accessibilityValue(AppTestOpsAccessibility.requestReference(request.id))
    }

    private var cancelButton: some View {
        Button {
            onCancelRequest(request)
        } label: {
            DesignQuietAction(
                title: store.isCancelling(request) ? "Cancelling" : "Cancel request",
                systemImage: store.isCancelling(request) ? "hourglass" : "xmark.circle",
                isDestructive: true
            )
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
        .disabled(!request.status.isOpenForOffers || store.isCancelling(request))
        .accessibilityLabel("Cancel request")
        .accessibilityIdentifier("customer.requests.cancel")
        .accessibilityValue(AppTestOpsAccessibility.requestReference(request.id))
    }
}

struct CustomerRequestCardActionsPresentation: Equatable, Sendable {
    let isOffersEnabled: Bool

    init(status: GroomingRequestStatus) {
        isOffersEnabled = status == .hasOffers
    }
}

struct CustomerClosedRequestsSection: View {
    let requests: [CustomerGroomingRequest]
    let store: CustomerRequestsStore
    let onRepublishRequest: (CustomerGroomingRequest) -> Void
    var title = "Closed requests"

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: title, systemImage: "clock.arrow.circlepath")
                .beckonEntrance(0)
            LazyVStack(spacing: DesignTokens.Spacing.md) {
                ForEach(Array(requests.enumerated()), id: \.element.id) { index, request in
                    NavigationLink {
                        CustomerRequestDetailView(
                            requestID: request.id,
                            store: store,
                            onRepublishRequest: onRepublishRequest
                        )
                    } label: {
                        CustomerClosedRequestRow(
                            request: request,
                            petAvatarPhotoData: store.primaryPetPhotoData(petID: request.petID)
                        )
                    }
                    .buttonStyle(BeckonLedgeButtonStyle(.card))
                    .beckonEntrance(1 + min(index, 4))
                    .accessibilityIdentifier(AppTestOpsAccessibility.requestIdentifier(
                        prefix: "customer.requests.history.row", requestID: request.id))
                }
            }
        }
    }
}

private struct CustomerClosedRequestRow: View {
    let request: CustomerGroomingRequest
    let petAvatarPhotoData: Data?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                requestSummary
                cancelledChip
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                requestSummary
                cancelledChip
            }
        }
        .padding(DesignTokens.Spacing.md)
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .combine)
    }

    private var requestSummary: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            BeckonPetAvatar(
                data: petAvatarPhotoData,
                systemImage: BeckonPetPresentation.symbol(for: request.petSnapshot.species),
                width: 48,
                height: 48,
                cornerRadius: 24
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(request.title)
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(request.preferredTimePresentation.summary)
                    .designSupportingText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cancelledChip: some View {
        BeckonStatusChip(request.status.presentation)
    }
}

struct CustomerRequestsEmptyDashboard: View {
    var body: some View {
        DesignPupPeek {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(CustomerRequestEmptyCopy.title)
                    .font(DesignTokens.Typography.Expressive.title)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text(CustomerRequestEmptyCopy.message)
                    .designSupportingText()
            }
            .designCardBody()
        }
    }
}

enum CustomerRequestEmptyCopy {
    static let title = "No active request"
    static let message = "Open requests and newly confirmed bookings will appear here."
}

private extension CustomerGroomingRequest {
    var progressCardHeadline: String {
        switch status {
        case .open:
            "Open\nrequest"
        case .hasOffers:
            "Offers\nready"
        case .booked:
            "Confirmed\nbooking"
        case .cancelled:
            "Cancelled\nrequest"
        case .expired:
            "Expired\nrequest"
        case .unknown:
            "Unknown\nstatus"
        }
    }

}
